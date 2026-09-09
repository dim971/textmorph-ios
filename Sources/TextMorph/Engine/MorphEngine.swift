// The state machine: what is on screen, what it is becoming, and when.
//
// This is upstream's text-morph/index.ts, minus the DOM. Three things about it
// are not obvious and all three come straight from the original.
//
// The clock is linear and nothing else. Every curve is applied by the plan, so
// the engine only ever needs to know how many milliseconds have passed. That is
// what lets an opacity window be a fraction of the duration rather than a
// fraction of the eased progress.
//
// A segment already on its way out when the next morph arrives keeps its own
// clock. Upstream's exit filter skips anything already marked exiting, so it
// carries on with the animation it had and removes itself when its fade closes.
// Here that is a ghost: a plan of its own with its own start time.
//
// Exactly one of the completion callbacks runs per morph. Not by care, but
// because the token that carries them can only fire once.

import Foundation
import SwiftUI

/// Carries a morph's completion callbacks, and can only fire once.
@MainActor
final class MorphToken {
    private var hasFired = false
    private let callbacks: MorphCallbacks

    init(_ callbacks: MorphCallbacks) {
        self.callbacks = callbacks
    }

    /// The morph ran its course.
    func complete() {
        guard !hasFired else { return }
        hasFired = true
        callbacks.onComplete?()
    }

    /// The morph was replaced before it finished.
    func cancel() {
        guard !hasFired else { return }
        hasFired = true
        callbacks.onCancel?()
    }

    /// Whether either has already run.
    var isSpent: Bool { hasFired }
}

/// One morph, and when it started.
struct RunningMorph {
    let plan: MorphPlan
    let startedAt: Date

    func elapsed(at now: Date) -> Double {
        max(0, now.timeIntervalSince(startedAt) * 1000)
    }

    func isFinished(at now: Date) -> Bool {
        elapsed(at: now) >= plan.durationMs
    }
}

/// Everything a draw pass needs for one frame.
struct RenderFrame {
    /// The morph in flight, with the state of every segment.
    let plan: MorphPlan
    let frame: MorphFrame
    /// Morphs that were interrupted and are still finishing their exits.
    let ghosts: [(plan: MorphPlan, frame: MorphFrame)]
    /// Whether anything at all is still moving.
    let isSettled: Bool
}

/// The morph a view owns.
@MainActor
final class MorphEngine {
    private let store: LineMeasuring

    private var options: TextMorphOptions
    private var alignment: MorphAlignment
    private var reduceMotion: Bool

    /// The value currently shown, already formatted.
    private(set) var text = ""
    /// The segments currently at rest, which the next diff runs against.
    private var segments: [Segment] = []
    /// Where they are, which is the layout the next morph starts from.
    private var layout: MorphLayout?

    /// Whether the next update is the first, which never animates and never
    /// fires a callback.
    private var isFirstValue = true

    private var running: RunningMorph?
    private var token: MorphToken?
    private var ghosts: [RunningMorph] = []

    /// One minter for the life of the view, so a numeric identity cannot be
    /// minted twice while the first one is still on screen.
    private let minter = MintedIds()

    init(
        store: LineMeasuring,
        options: TextMorphOptions = .default,
        alignment: MorphAlignment = .leading,
        reduceMotion: Bool = false
    ) {
        self.store = store
        self.options = options
        self.alignment = alignment
        self.reduceMotion = reduceMotion
    }

    /// Whether the morphing is off, for either reason.
    var isDisabled: Bool {
        options.disabled || (options.respectReducedMotion && reduceMotion)
    }

    /// The size the container should report right now.
    func size(at now: Date) -> MorphSize {
        guard let running else {
            guard let layout else { return .zero }
            return MorphSize(width: layout.width, height: layout.height)
        }
        let frame = running.plan.frame(atElapsed: running.elapsed(at: now))
        return MorphSize(width: frame.width, height: frame.height)
    }

    /// Where the first line's baseline sits, so a morph lines up with a `Text`.
    var firstBaseline: Double { layout?.firstBaseline ?? 0 }

    // MARK: - configuration

    /// Applies a new configuration.
    ///
    /// A change that alters what a morph would look like takes effect on the
    /// next value rather than restarting the one in flight, which is what
    /// upstream's config key achieves by only tearing the instance down when
    /// something it cares about changed.
    func configure(
        options: TextMorphOptions, alignment: MorphAlignment, reduceMotion: Bool
    ) {
        let wasDisabled = isDisabled
        self.options = options
        self.alignment = alignment
        self.reduceMotion = reduceMotion

        // Coming back from disabled, the segments on screen were never
        // measured, so a diff against them would animate from boxes that never
        // existed. Upstream resets its own two fields for exactly this reason.
        if wasDisabled, !isDisabled { forget() }
        if !wasDisabled, isDisabled { settleImmediately() }
    }

    /// Drops what is on screen, so the next value arrives without animating.
    private func forget() {
        segments = []
        layout = nil
        isFirstValue = true
        running = nil
        ghosts = []
        token = nil
    }

    /// Stops everything where it should have ended up.
    private func settleImmediately() {
        running = nil
        ghosts = []
        // Deliberately not cancelled: upstream fires neither callback on this
        // path, because the morph did not fail, it was switched off.
        token = nil
    }

    // MARK: - the value

    /// Shows a new value.
    ///
    /// Returns whether anything changed, so a caller can tell a no-op from a
    /// morph. An update whose formatted value equals the one already shown does
    /// nothing at all, not even fire `onStart`, which is upstream's first line.
    @discardableResult
    func update(
        _ value: MorphValue,
        cursorIndex: Int? = nil,
        callbacks: MorphCallbacks = MorphCallbacks(),
        now: Date = Date()
    ) -> Bool {
        // Upstream's first line, and it comes before everything including
        // `onStart`: an update that does not change the formatted value is not
        // a morph. One consequence is that showing an empty value first does
        // nothing at all, since the engine starts out showing one.
        let formatted = options.formatted(value)
        guard formatted != text else { return false }
        text = formatted

        if isDisabled {
            settle(formatted)
            return true
        }

        if isFirstValue {
            first(formatted)
            return true
        }

        callbacks.onStart?()
        morph(formatted, cursorIndex: cursorIndex, callbacks: callbacks, now: now)
        return true
    }

    /// The value arrives already in place: no plan, no clock, no callbacks.
    private func settle(_ formatted: String) {
        segments = TextSegmenter.segmentText(
            formatted, locale: options.locale, numbers: options.numbers, minter: minter
        )
        layout = store.layout(segments, alignment: alignment)
        // A later diff against these would animate from boxes that were never
        // on screen, so the next enabled morph starts fresh.
        isFirstValue = true
        running = nil
        ghosts = []
    }

    /// The first value a view shows, which never animates.
    private func first(_ formatted: String) {
        segments = TextSegmenter.segmentText(
            formatted, locale: options.locale, numbers: options.numbers, minter: minter
        )
        let layout = store.layout(segments, alignment: alignment)
        self.layout = layout
        isFirstValue = false
        running = RunningMorph(
            plan: MorphPlanner.still(layout, segments: segments), startedAt: .distantPast
        )
    }

    private func morph(
        _ formatted: String, cursorIndex: Int?, callbacks: MorphCallbacks, now: Date
    ) {
        guard let oldLayout = layout else {
            first(formatted)
            return
        }

        // What was on screen becomes a ghost, so anything already leaving keeps
        // its own clock and finishes its own fade.
        let carried = carriedStates(at: now)
        if let running, !running.isFinished(at: now) {
            token?.cancel()
            ghosts.append(running)
        }
        ghosts = ghosts.filter { !$0.isFinished(at: now) }

        let result = SegmentDiff.diffSegments(
            segments,
            formatted,
            locale: options.locale,
            options: DiffOptions(
                numbers: options.numbers,
                cursorIndex: cursorIndex.map { UTF16Offset($0) }
            ),
            minter: minter
        )

        // A value that empties out keeps a zero-width stand-in in the flow, so
        // the line box does not collapse while the last segments are still
        // leaving.
        let isEmpty = result.segments.isEmpty
        let newSegments = isEmpty
            ? [Segment(id: Segment.emptyID, string: "\u{200B}")]
            : result.segments

        // The old segments are cut finer before being measured, exactly as
        // upstream splits the spans before reading their boxes.
        let split = applySplits(segments, result.splits)
        let splitLayout = result.splits.isEmpty
            ? oldLayout
            : store.layout(split, alignment: alignment)

        let newLayout = store.layout(newSegments, alignment: alignment)
        let firstFrame = store.layout(
            newSegments, alignment: alignment, containerWidth: splitLayout.width
        )

        let resolved = options.ease.resolve(fallbackDuration: options.duration)
        let plan = MorphPlanner.plan(MorphPlanInput(
            oldSegments: split,
            newSegments: newSegments,
            oldLayout: splitLayout,
            newLayout: newLayout,
            firstFrameLayout: firstFrame,
            durationMs: resolved.durationMs,
            curve: resolved.curve,
            scale: options.scale,
            carried: carried,
            isEmptyTransition: isEmpty
        ))

        segments = newSegments
        layout = newLayout
        running = RunningMorph(plan: plan, startedAt: now)
        token = MorphToken(callbacks)
    }

    // MARK: - frames

    /// The frame to draw at a moment, firing a completion that has come due.
    ///
    /// The callback is fired from here rather than from a timer so it cannot
    /// run before the frame that finished the morph has been drawn, and cannot
    /// run at all for a morph that was replaced first.
    func render(at now: Date) -> RenderFrame? {
        guard let running else { return nil }

        ghosts = ghosts.filter { !$0.isFinished(at: now) }
        let elapsed = running.elapsed(at: now)
        let frame = running.plan.frame(atElapsed: elapsed)

        if frame.isFinished, let token, !token.isSpent {
            token.complete()
        }

        return RenderFrame(
            plan: running.plan,
            frame: frame,
            ghosts: ghosts.map {
                ($0.plan, $0.plan.frame(atElapsed: $0.elapsed(at: now)))
            },
            isSettled: frame.isFinished && ghosts.isEmpty
        )
    }

    /// Where every segment is right now, for a morph interrupting another.
    ///
    /// Only the displacement and the opacity. Upstream reads exactly those two
    /// back off the running animation and lets the scale restart.
    private func carriedStates(at now: Date) -> [String: SegmentState] {
        guard let running, !running.isFinished(at: now) else { return [:] }
        let frame = running.plan.frame(atElapsed: running.elapsed(at: now))

        var out: [String: SegmentState] = [:]
        for (animation, state) in zip(running.plan.segments, frame.states)
            where !animation.role.isLeaving {
            out[animation.id] = SegmentState(
                dx: state.dx, dy: state.dy, opacity: state.opacity, moverDy: state.moverDy
            )
        }
        return out
    }

    /// Substitutes the finer spans the diff asked for.
    private func applySplits(
        _ segments: [Segment], _ splits: [String: [Segment]]
    ) -> [Segment] {
        guard !splits.isEmpty else { return segments }
        return segments.flatMap { splits[$0.id] ?? [$0] }
    }
}
