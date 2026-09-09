import Foundation
import Testing
@testable import TextMorph

/// A store that measures with the made-up monospace metric.
@MainActor
struct SyntheticStore: LineMeasuring {
    func metrics(for text: String) -> ShapedLineMetrics {
        SyntheticMetrics.metrics(for: text)
    }
}

/// Counts what the engine reported, so a test can assert on it.
@MainActor
final class CallbackLog {
    var started = 0
    var completed = 0
    var cancelled = 0

    var callbacks: MorphCallbacks {
        MorphCallbacks(
            onStart: { [self] in started += 1 },
            onComplete: { [self] in completed += 1 },
            onCancel: { [self] in cancelled += 1 }
        )
    }

    /// Every morph should account for exactly one of these two.
    var settled: Int { completed + cancelled }
}

/// The state machine, on a clock the test controls.
///
/// The parts of upstream exercised here are the ones its own React wrapper does
/// not even reach: it never wires `onAnimationCancel`, so the interruption path
/// is unexercised there. That makes it the most likely place for the two ports
/// to be wrong in different ways, which is why the clock is a parameter and the
/// sequences are scripted.
@Suite("The morph engine")
@MainActor
struct MorphEngineTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    private func engine(
        _ options: TextMorphOptions = .default, reduceMotion: Bool = false
    ) -> MorphEngine {
        MorphEngine(
            store: SyntheticStore(), options: options,
            alignment: .leading, reduceMotion: reduceMotion
        )
    }

    // MARK: - the first value

    @Test("The first value arrives in place and reports nothing")
    func firstValue() throws {
        let engine = engine()
        let log = CallbackLog()

        #expect(engine.update(.text("Total"), callbacks: log.callbacks, now: start))
        #expect(log.started == 0, "the first value is not a morph")
        #expect(log.settled == 0)

        let render = try #require(engine.render(at: start))
        #expect(render.isSettled)
        for state in render.frame.states {
            #expect(state == .resting)
        }
        #expect(engine.size(at: start).width == 5 * SyntheticMetrics.advance)
    }

    @Test("An update that changes nothing is not a morph at all")
    func noOpUpdate() {
        let engine = engine()
        let log = CallbackLog()
        engine.update(.text("Total"), now: start)

        #expect(!engine.update(.text("Total"), callbacks: log.callbacks, now: start))
        #expect(log.started == 0, "not even onStart, which is upstream's first line")
        #expect(log.settled == 0)
    }

    @Test("A number that formats to the same string is the same value")
    func numericNoOp() {
        let engine = engine(TextMorphOptions(decimals: 0))
        engine.update(.number(1.4), now: start)
        #expect(engine.text == "1")
        // Both round to the same string, so the second is not a change.
        #expect(!engine.update(.number(1.2), now: start))
    }

    // MARK: - one morph

    @Test("A morph reports its start once, and its completion once")
    func oneMorph() throws {
        let engine = engine()
        let log = CallbackLog()
        engine.update(.text("one"), now: start)

        engine.update(.text("one two"), callbacks: log.callbacks, now: start)
        #expect(log.started == 1)
        #expect(log.settled == 0)

        // Part way through: nothing has settled.
        _ = engine.render(at: start.addingTimeInterval(0.2))
        #expect(log.settled == 0)

        // Past the end.
        let render = try #require(engine.render(at: start.addingTimeInterval(0.4)))
        #expect(render.isSettled)
        #expect(log.completed == 1)
        #expect(log.cancelled == 0)

        // Drawing again does not report it twice.
        _ = engine.render(at: start.addingTimeInterval(1))
        #expect(log.completed == 1)
    }

    // MARK: - interruption

    @Test("A morph replaced before it finished is cancelled, never completed")
    func interruptedMorph() {
        let engine = engine()
        let first = CallbackLog()
        let second = CallbackLog()
        engine.update(.text("one"), now: start)

        engine.update(.text("one two"), callbacks: first.callbacks, now: start)
        _ = engine.render(at: start.addingTimeInterval(0.1))

        engine.update(
            .text("one two three"), callbacks: second.callbacks,
            now: start.addingTimeInterval(0.1)
        )
        #expect(first.cancelled == 1)
        #expect(first.completed == 0)
        #expect(second.started == 1)

        _ = engine.render(at: start.addingTimeInterval(0.6))
        #expect(second.completed == 1)
        // The first morph is still accounted for exactly once.
        #expect(first.settled == 1)
    }

    @Test("Twenty updates in a row account for every morph exactly once")
    func rapidUpdates() {
        let engine = engine()
        var logs: [CallbackLog] = []
        engine.update(.text("0"), now: start)

        // Eight milliseconds apart, which is faster than a frame at 120Hz and
        // far faster than the 400ms morph settles.
        for step in 1 ... 20 {
            let log = CallbackLog()
            logs.append(log)
            let now = start.addingTimeInterval(Double(step) * 0.008)
            engine.update(.number(Double(step) * 137), callbacks: log.callbacks, now: now)
            _ = engine.render(at: now)
        }

        // Let the last one finish.
        _ = engine.render(at: start.addingTimeInterval(10))

        for (index, log) in logs.enumerated() {
            #expect(log.started == 1, "morph \(index) should have started once")
            #expect(log.settled == 1, "morph \(index) should have settled exactly once")
        }
        // Every one but the last was replaced.
        #expect(logs.dropLast().allSatisfy { $0.cancelled == 1 })
        #expect(logs.last?.completed == 1)
    }

    @Test("A rapid run of values never makes a segment jump")
    func noJumpsUnderPressure() {
        let engine = engine()
        engine.update(.number(1000), now: start)

        var previous: [String: SegmentState] = [:]
        var worstJump = 0.0

        // Sampled every four milliseconds while the value changes every
        // twenty, so most frames fall inside a morph and some fall on the
        // moment one replaces another.
        for step in 1 ... 200 {
            let now = start.addingTimeInterval(Double(step) * 0.004)
            if step % 5 == 0 {
                engine.update(.number(1000 + Double(step) * 7), now: now)
            }
            guard let render = engine.render(at: now) else { continue }

            var current: [String: SegmentState] = [:]
            for (animation, state) in zip(render.plan.segments, render.frame.states) {
                current[animation.id] = state
                guard let was = previous[animation.id] else { continue }
                worstJump = max(worstJump, abs(state.dx - was.dx))
                worstJump = max(worstJump, abs(state.dy - was.dy))
            }
            previous = current
        }

        // One character of the synthetic font is ten units. A segment moving
        // more than a character between two frames four milliseconds apart is
        // the box crawling and then snapping, which is what carrying the state
        // across an interruption is for.
        #expect(
            worstJump < SyntheticMetrics.advance,
            Comment(rawValue: "worst jump \(worstJump), which is more than a character")
        )
    }

    @Test("Segments already leaving keep their own clock")
    func ghostsFinishTheirOwnExit() throws {
        let engine = engine()
        engine.update(.text("alpha beta"), now: start)
        engine.update(.text("alpha"), now: start)

        // Interrupted a tenth of the way in, while "beta" is still leaving.
        let interruptedAt = start.addingTimeInterval(0.04)
        _ = engine.render(at: interruptedAt)
        engine.update(.text("alpha gamma"), now: interruptedAt)

        let during = try #require(engine.render(at: interruptedAt))
        #expect(!during.ghosts.isEmpty, "the interrupted morph should still be drawn")
        #expect(!during.isSettled)

        // The ghost is dropped once its own plan has run its course.
        let after = try #require(engine.render(at: start.addingTimeInterval(2)))
        #expect(after.ghosts.isEmpty)
        #expect(after.isSettled)
    }

    // MARK: - switched off

    @Test("Disabled, a value arrives in place and reports nothing")
    func disabled() {
        let engine = engine(TextMorphOptions(disabled: true))
        let log = CallbackLog()
        engine.update(.text("one"), now: start)
        engine.update(.text("one two"), callbacks: log.callbacks, now: start)

        #expect(log.started == 0)
        #expect(log.settled == 0, "upstream fires neither callback on this path")
        #expect(engine.render(at: start) == nil, "there is nothing to animate")
        #expect(engine.size(at: start).width == 7 * SyntheticMetrics.advance)
    }

    @Test("Reduce motion is honoured, unless the caller says not to")
    func reduceMotion() {
        let honouring = engine(reduceMotion: true)
        #expect(honouring.isDisabled)

        let ignoring = engine(
            TextMorphOptions(respectReducedMotion: false), reduceMotion: true
        )
        #expect(!ignoring.isDisabled)
    }

    @Test("Coming back from disabled, the next value arrives without animating")
    func reEnabling() throws {
        // The segments on screen while disabled were never measured as part of
        // a morph, so a diff against them would animate from boxes that never
        // existed. Upstream resets for exactly this reason.
        let engine = engine(TextMorphOptions(disabled: true))
        engine.update(.text("one"), now: start)
        engine.update(.text("one two"), now: start)

        engine.configure(options: .default, alignment: .leading, reduceMotion: false)
        let log = CallbackLog()
        engine.update(.text("one two three"), callbacks: log.callbacks, now: start)

        #expect(log.started == 0, "the first value after re-enabling is a first value")
        let render = try #require(engine.render(at: start))
        #expect(render.isSettled)
    }
}
