import Foundation
import Testing
@testable import TextMorph

/// The plan, and the function both ports sample.
///
/// These are not fixtures of upstream behaviour, because upstream has no plan:
/// it writes keyframes and lets the browser interpolate them. What can be
/// asserted is that the plan says the same thing those keyframes say, and that
/// the sampling function is pure, total and lands exactly at rest. The timing
/// table it is checked against is `MorphTiming`, which carries upstream's own
/// numbers under upstream's own names.
@Suite("The morph plan")
struct MorphPlanTests {
    // MARK: - the first render

    @Test("A value appearing for the first time does not move")
    func stillPlan() {
        let segments = TextSegmenter.segmentText("Total balance")
        let layout = SyntheticMetrics.layout(segments)
        let plan = MorphPlanner.still(layout, segments: segments)

        #expect(plan.durationMs == 0)
        #expect(plan.segments.count == layout.boxes.count)
        for elapsed in [-100.0, 0, 1, 400, 100_000] {
            let frame = plan.frame(atElapsed: elapsed)
            #expect(frame.isFinished)
            #expect(frame.width == layout.width)
            for state in frame.states {
                #expect(state == .resting)
            }
        }
    }

    // MARK: - a segment that stays

    @Test("A segment that stays starts where it was and ends at rest")
    func persistingSegment() throws {
        // "Total" survives and moves right by one word plus a space, which is
        // six characters of the synthetic font.
        let morph = SyntheticMorph(from: "Total x", to: "x Total")
        let total = try #require(morph.animation("Total"))

        #expect(total.role == .persist)
        #expect(total.source == .new)
        // Was at 0, will be at 20. The inverse delta is where it was minus
        // where it is going.
        #expect(total.box.x == 2 * SyntheticMetrics.advance)
        #expect(total.from.dx == -2 * SyntheticMetrics.advance)
        #expect(total.to.dx == 0)
        #expect(total.from.scale == 1)
        #expect(total.from.opacity == 1)

        // Fully opaque and merely moving, so there is no fade at all.
        #expect(total.fadeWindow.start == total.fadeWindow.end)

        let settled = try #require(morph.state("Total", atElapsed: 400))
        #expect(settled.dx == 0)
        #expect(settled.dy == 0)
        #expect(settled.scale == 1)
        #expect(settled.opacity == 1)
    }

    // MARK: - a segment that arrives

    @Test("A segment that arrives fades in over half the morph, a quarter late")
    func arrivingSegment() throws {
        let morph = SyntheticMorph(from: "one", to: "one two")
        let two = try #require(morph.animation("two"))

        #expect(two.role == .enter)
        #expect(two.from.opacity == 0)
        #expect(two.to.opacity == 1)
        #expect(two.from.scale == MorphTiming.segmentScale)
        #expect(two.to.scale == 1)
        #expect(two.fadeWindow.start == MorphTiming.enterFadeDelay)
        #expect(two.fadeWindow.end == MorphTiming.enterFadeDelay + MorphTiming.enterFade)

        // Still invisible through the delay, then linear to one.
        #expect(morph.state("two", atElapsed: 0)?.opacity == 0)
        #expect(morph.state("two", atElapsed: 100)?.opacity == 0)
        #expect(morph.state("two", atElapsed: 200)?.opacity == 0.5)
        #expect(morph.state("two", atElapsed: 300)?.opacity == 1)
        #expect(morph.state("two", atElapsed: 400)?.opacity == 1)
    }

    // MARK: - a segment that leaves

    @Test("A segment that leaves follows what takes its place, and fades early")
    func leavingSegment() throws {
        let morph = SyntheticMorph(from: "one two", to: "one")
        let two = try #require(morph.animation("two"))

        #expect(two.role == .exit)
        #expect(two.source == .old)
        #expect(two.from == SegmentState())
        #expect(two.to.opacity == 0)
        #expect(two.to.scale == MorphTiming.segmentScale)
        #expect(two.fadeWindow.start == 0)
        #expect(two.fadeWindow.end == MorphTiming.exitFade)

        // Gone a quarter of the way in, which is earlier than an arriving
        // segment even starts: a character that has already left is a hole.
        #expect(morph.state("two", atElapsed: 0)?.opacity == 1)
        #expect(morph.state("two", atElapsed: 50)?.opacity == 0.5)
        #expect(morph.state("two", atElapsed: 100)?.opacity == 0)
    }

    @Test("Turning the scale off only affects what leaves")
    func scaleOption() {
        let with = SyntheticMorph(from: "one two", to: "one")
        let without = SyntheticMorph(from: "one two", to: "one", scale: false)
        #expect(with.animation("two")?.to.scale == MorphTiming.segmentScale)
        #expect(without.animation("two")?.to.scale == 1)

        // An arriving segment scales either way, which is upstream: the option
        // is only read on the exit path.
        let arriving = SyntheticMorph(from: "one", to: "one two", scale: false)
        #expect(arriving.animation("two")?.from.scale == MorphTiming.segmentScale)
    }

    // MARK: - numbers

    @Test("A digit arrives from above and a symbol from below")
    func numberSlide() {
        let morph = SyntheticMorph(from: "1", to: "1.5")
        let slide = morph.plan.slideDistance
        #expect(slide == SyntheticMetrics.ascent + SyntheticMetrics.descent)

        let entering = morph.animations(in: .numberEnter)
        #expect(!entering.isEmpty)
        for animation in entering {
            #expect(animation.to.moverDy == 0)
            switch animation.kind {
            case .digit: #expect(animation.from.moverDy == -slide)
            case .symbol: #expect(animation.from.moverDy == slide)
            case nil: Issue.record("a number's character must carry a kind")
            }
            #expect(animation.fadeWindow.end == MorphTiming.numberEnterFade)
        }
    }

    @Test("A digit leaving slides out and fades over nearly half the morph")
    func numberExit() {
        let morph = SyntheticMorph(from: "1.5", to: "1")
        let leaving = morph.animations(in: .numberExit)
        #expect(!leaving.isEmpty)
        for animation in leaving {
            #expect(animation.from.moverDy == 0)
            // Out along the block axis, whichever kind it is: what differs is
            // the direction they arrive from, not the direction they go.
            #expect(animation.to.moverDy == morph.plan.slideDistance)
            #expect(animation.fadeWindow.end == MorphTiming.numberExitFade)
        }
    }

    @Test("A number's slot never scales")
    func numbersDoNotScale() {
        let morph = SyntheticMorph(from: "1,204", to: "1,318")
        let numbers = morph.plan.segments.filter(\.role.isNumber)
        #expect(!numbers.isEmpty)
        for animation in numbers {
            #expect(animation.from.scale == 1)
            #expect(animation.to.scale == 1)
        }
    }

    // MARK: - a run replaced as one shape

    @Test("A long enough run collapses towards its own centre and does not travel")
    func replacedRun() {
        // Nothing in common, and long enough on both sides.
        let morph = SyntheticMorph(from: "abcdefghij", to: "KLMNOPQRST", numbers: false)

        let leaving = morph.animations(in: .groupExit)
        let arriving = morph.animations(in: .groupEnter)
        #expect(leaving.count >= MorphTiming.groupMinimum)
        #expect(arriving.count >= MorphTiming.groupMinimum)

        for animation in leaving {
            // No displacement at all: upstream's group animation replaces the
            // transform rather than composing with it.
            #expect(animation.from.dx == 0)
            #expect(animation.to.dx == 0)
            #expect(animation.from.dy == 0)
            #expect(animation.to.dy == 0)
            #expect(animation.to.scale == MorphTiming.groupScale)
            #expect(animation.fadeWindow.end == MorphTiming.groupExitFade)
        }
        for animation in arriving {
            #expect(animation.from.scale == MorphTiming.groupScale)
            #expect(animation.to.scale == 1)
            #expect(animation.fadeWindow.end == MorphTiming.groupEnterFade)
        }

        // Every member of a run scales about the same point.
        #expect(Set(leaving.map(\.scaleOrigin)).count == 1)
        #expect(Set(arriving.map(\.scaleOrigin)).count == 1)
    }

    @Test("A run broken by a survivor is not a replacement")
    func survivorBreaksTheRun() {
        // The "x" survives in the middle, so neither half is long enough on its
        // own and every character animates individually. That survivor is right
        // there to move relative to.
        let morph = SyntheticMorph(from: "abcxdefg", to: "hijxklmn", numbers: false)
        #expect(morph.animations(in: .groupExit).isEmpty)
        #expect(morph.animations(in: .groupEnter).isEmpty)
    }

    // MARK: - sampling

    @Test("Sampling is total, and lands exactly at rest")
    func samplingIsTotal() {
        let morph = SyntheticMorph(from: "1,204 apples", to: "1,318 pears")

        for elapsed in [-1000.0, -1, 0, 1, 200, 399, 400, 401, 100_000] {
            let frame = morph.plan.frame(atElapsed: elapsed)
            #expect(frame.states.count == morph.plan.segments.count)
            for state in frame.states {
                #expect(state.dx.isFinite)
                #expect(state.dy.isFinite)
                #expect(state.opacity >= 0)
                #expect(state.opacity <= 1)
            }
        }

        // At and past the end, everything that stays is exactly at rest and
        // exactly opaque. Not nearly: a segment left a hair off its box would
        // be measured as displaced by the next morph.
        let settled = morph.plan.frame(atElapsed: 400)
        #expect(settled.isFinished)
        for (animation, state) in zip(morph.plan.segments, settled.states)
            where !animation.role.isLeaving {
            #expect(state.dx == 0)
            #expect(state.dy == 0)
            #expect(state.scale == 1)
            #expect(state.opacity == 1)
            #expect(state.moverDy == 0)
        }
    }

    @Test("Opacity runs on linear time even when the curve does not")
    func opacityIgnoresTheCurve() {
        // The whole reason the clock stays linear. Under the default curve the
        // eased progress at the halfway point is far past half, and the fade
        // must not be.
        let morph = SyntheticMorph(from: "one", to: "one two")
        let eased = morph.plan.curve.value(at: 0.5)
        #expect(eased > 0.8, "the default curve is well past half at half time")

        // The window is [0.25, 0.75] of 400ms, so 300ms is exactly halfway
        // through it.
        #expect(morph.state("two", atElapsed: 300)?.opacity == 1)
        #expect(morph.state("two", atElapsed: 200)?.opacity == 0.5)
        #expect(morph.state("two", atElapsed: 150)?.opacity == 0.25)
    }

    // MARK: - the container

    @Test("The container's two axes run from the old size to the new one")
    func containerAxes() {
        let morph = SyntheticMorph(from: "one", to: "one two")
        #expect(morph.plan.container.width.from == 3 * SyntheticMetrics.advance)
        #expect(morph.plan.container.width.to == 7 * SyntheticMetrics.advance)
        #expect(morph.plan.container.height.from == morph.plan.container.height.to)

        #expect(morph.plan.frame(atElapsed: 0).width == 3 * SyntheticMetrics.advance)
        #expect(morph.plan.frame(atElapsed: 400).width == 7 * SyntheticMetrics.advance)
    }

    @Test("An axis whose curve began earlier is already part way through it")
    func containerClockOffset() {
        // This is what keeps a fast counter's box from crawling: an axis whose
        // target has not moved resumes at the phase it had reached instead of
        // playing the opening sliver of the curve again.
        let curve = EasingCurve.bezier(.default)
        let fresh = ContainerAxis(from: 0, to: 100, curve: curve)
        let resumed = ContainerAxis(from: 0, to: 100, curve: curve, clockOffsetMs: 200)

        #expect(fresh.value(atElapsed: 0, duration: 400) == 0)
        #expect(resumed.value(atElapsed: 0, duration: 400) > 80)
        #expect(resumed.value(atElapsed: 400, duration: 400) == 100)
    }

    @Test("An emptying value holds its old box rather than collapsing")
    func emptyTransitionHolds() {
        let segments = TextSegmenter.segmentText("something")
        let old = SyntheticMetrics.layout(segments)
        let stand = [Segment(id: Segment.emptyID, string: "\u{200B}")]
        let new = SyntheticMetrics.layout(stand)

        let plan = MorphPlanner.plan(MorphPlanInput(
            oldSegments: segments,
            newSegments: stand,
            oldLayout: old,
            newLayout: new,
            firstFrameLayout: new,
            durationMs: 400,
            curve: .bezier(.default),
            isEmptyTransition: true
        ))

        // Held, not animated: a container collapsing to nothing takes the line
        // box with it and the segments still leaving would jump.
        #expect(plan.frame(atElapsed: 0).width == old.width)
        #expect(plan.frame(atElapsed: 200).width == old.width)
        #expect(plan.frame(atElapsed: 400).width == old.width)

        // The stand-in itself is never drawn.
        #expect(!plan.segments.contains { $0.id == Segment.emptyID })
    }

    // MARK: - overshoot

    @Test("Overshoot is nothing for the default curve and real for the default spring")
    func overshoot() {
        let bezier = SyntheticMorph(from: "a", to: "b", numbers: false)
        #expect(bezier.plan.overshoot == 0)

        let resolved = TextMorphEase.spring().resolve(fallbackDuration: 400)
        let sprung = SyntheticMorph(
            from: "a", to: "b", durationMs: resolved.durationMs,
            curve: resolved.curve, numbers: false
        )
        // A glyph clipped at the peak of its bounce is a bug that only appears
        // with springs, so the surface has to know about this.
        #expect(sprung.plan.overshoot > 0.1)
        #expect(sprung.plan.overshoot < 0.25)
    }

    // MARK: - interruption

    @Test("An interrupted morph carries its position and opacity, not its scale")
    func carriedState() throws {
        // Upstream reads exactly the translation and the opacity back off the
        // running animation, so a segment interrupted mid-shrink snaps to full
        // size and carries on from where it had travelled to.
        let carried = ["Total": SegmentState(dx: 7, dy: 3, scale: 0.5, opacity: 0.4)]
        let morph = SyntheticMorph(from: "Total x", to: "x Total", carried: carried)
        let total = try #require(morph.animation("Total"))

        #expect(total.from.dx == -2 * SyntheticMetrics.advance + 7)
        #expect(total.from.dy == 3)
        #expect(total.from.opacity == 0.4)
        #expect(total.from.scale == 1, "the scale restarts rather than being carried")

        // Part way through a fade when it was interrupted, so it finishes the
        // fade over the persist window rather than not fading at all.
        #expect(total.fadeWindow.end == MorphTiming.persistFade)
    }
}
