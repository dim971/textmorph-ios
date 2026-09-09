import Foundation
@testable import TextMorph

/// A made-up monospace font, so a plan can be asserted in whole numbers.
///
/// Every UTF-16 unit advances by the same amount, so a displacement is a
/// multiple of it and a failure reads as "expected 30, got 20" rather than as
/// two similar decimals. It also means these tests say nothing about any real
/// font, which is the point: the shaping is tested against pixels elsewhere,
/// and what is being tested here is the arithmetic of the plan.
///
/// The Android twin can build the same metric and replay the same assertions,
/// which is the only way a claim about the two agreeing is checkable.
enum SyntheticMetrics {
    static let advance = 10.0
    static let ascent = 8.0
    static let descent = 2.0
    static let leading = 0.0

    /// The metrics of one line under the synthetic font.
    static func metrics(for text: String) -> ShapedLineMetrics {
        let length = text.utf16.count
        return ShapedLineMetrics(
            width: Double(length) * advance,
            ascent: ascent,
            descent: descent,
            leading: leading,
            offsets: (0 ... length).map { Double($0) * advance }
        )
    }

    /// Lays a value's segments out under the synthetic font.
    static func layout(
        _ segments: [Segment],
        alignment: MorphAlignment = .leading,
        containerWidth: Double? = nil
    ) -> MorphLayout {
        let lines = LineLayout.lines(of: segments)
        return LineLayout.layout(
            lines: lines,
            metrics: lines.map { metrics(for: $0.text) },
            alignment: alignment,
            containerWidth: containerWidth
        )
    }
}

/// One morph, set up the way the engine will set it up.
struct SyntheticMorph {
    let oldSegments: [Segment]
    let newSegments: [Segment]
    let plan: MorphPlan

    /// Runs a value through the segmenter, the diff, the layout and the planner.
    init(
        from before: String,
        to after: String,
        durationMs: Double = 400,
        curve: EasingCurve = .bezier(.default),
        scale: Bool = true,
        numbers: Bool = true,
        alignment: MorphAlignment = .leading,
        carried: [String: SegmentState] = [:]
    ) {
        let minter = MintedIds()
        let previous = TextSegmenter.segmentText(
            before, locale: defaultMorphLocale, numbers: numbers, minter: minter
        )
        let result = SegmentDiff.diffSegments(
            previous,
            after,
            locale: defaultMorphLocale,
            options: DiffOptions(numbers: numbers),
            minter: minter
        )

        // The old segments are cut finer before being measured, exactly as
        // upstream splits the spans before reading their boxes.
        let split = SyntheticMorph.applySplits(previous, result.splits)

        let oldLayout = SyntheticMetrics.layout(split, alignment: alignment)
        let newLayout = SyntheticMetrics.layout(result.segments, alignment: alignment)
        let firstFrame = SyntheticMetrics.layout(
            result.segments, alignment: alignment, containerWidth: oldLayout.width
        )

        oldSegments = split
        newSegments = result.segments
        plan = MorphPlanner.plan(MorphPlanInput(
            oldSegments: split,
            newSegments: result.segments,
            oldLayout: oldLayout,
            newLayout: newLayout,
            firstFrameLayout: firstFrame,
            durationMs: durationMs,
            curve: curve,
            scale: scale,
            carried: carried
        ))
    }

    /// Substitutes the finer spans the diff asked for.
    static func applySplits(
        _ segments: [Segment], _ splits: [String: [Segment]]
    ) -> [Segment] {
        guard !splits.isEmpty else { return segments }
        return segments.flatMap { splits[$0.id] ?? [$0] }
    }

    /// The animation for one identity, if the plan has one.
    func animation(_ id: String) -> SegmentAnimation? {
        plan.segments.first { $0.id == id }
    }

    /// The animations in one role.
    func animations(in role: SegmentRole) -> [SegmentAnimation] {
        plan.segments.filter { $0.role == role }
    }

    /// The state of one identity at a moment.
    func state(_ id: String, atElapsed elapsed: Double) -> SegmentState? {
        guard let index = plan.segments.firstIndex(where: { $0.id == id }) else { return nil }
        return plan.frame(atElapsed: elapsed).states[index]
    }
}
