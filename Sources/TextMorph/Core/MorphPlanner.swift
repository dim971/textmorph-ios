// Turning two layouts and a diff into a plan.
//
// This replaces upstream's flip.ts together with the orchestration half of
// text-morph/index.ts, and it is where the direction of every displacement is
// decided. Two things about it are easy to get backwards and both are load
// bearing.
//
// A segment that survives, or arrives, is displaced by the *inverse* delta: it
// starts where it used to be and animates to nothing. A segment that leaves is
// displaced by the *forward* delta of whatever it anchors to: it starts at
// nothing and travels to where that anchor went. Those are the two halves of
// the same gesture, and swapping either makes the morph read backwards.
//
// A run of at least six adjacent segments all leaving, or all arriving, carries
// no displacement at all. It scales about the run's own centre instead.
// Upstream's group animation *replaces* the transform rather than composing
// with it, which is easy to miss and produces a run that both travels and
// collapses if it is missed.

/// What the planner needs to know.
public struct MorphPlanInput {
    /// The segments already on screen, with any splits already applied.
    public let oldSegments: [Segment]
    /// The segments the new value wants.
    public let newSegments: [Segment]

    /// Where the old segments were.
    public let oldLayout: MorphLayout
    /// Where the new segments will settle.
    public let newLayout: MorphLayout

    /// The new segments laid out at the width the container had a moment ago.
    ///
    /// This is what upstream buys by writing the old width onto the element and
    /// forcing a reflow before measuring. It only differs from `newLayout` for
    /// a centred or trailing value, and for those it is the difference between
    /// the text holding still and the whole line sliding sideways.
    public let firstFrameLayout: MorphLayout

    /// How long the morph takes, in milliseconds.
    public let durationMs: Double
    /// The curve every displacement follows.
    public let curve: EasingCurve
    /// Whether a leaving segment shrinks as it goes.
    public let scale: Bool

    /// Where each segment already was, for a morph interrupting another.
    ///
    /// Only the displacement and the opacity are carried. Upstream reads
    /// exactly those two back off the running animation and lets the scale
    /// restart, so a segment interrupted mid-shrink snaps to full size and
    /// carries on from where it had travelled to.
    public let carried: [String: SegmentState]

    /// Set when the new value is empty and a stand-in is holding the line box.
    public let isEmptyTransition: Bool

    /// Creates planner input.
    public init(
        oldSegments: [Segment],
        newSegments: [Segment],
        oldLayout: MorphLayout,
        newLayout: MorphLayout,
        firstFrameLayout: MorphLayout,
        durationMs: Double,
        curve: EasingCurve,
        scale: Bool = true,
        carried: [String: SegmentState] = [:],
        isEmptyTransition: Bool = false
    ) {
        self.oldSegments = oldSegments
        self.newSegments = newSegments
        self.oldLayout = oldLayout
        self.newLayout = newLayout
        self.firstFrameLayout = firstFrameLayout
        self.durationMs = durationMs
        self.curve = curve
        self.scale = scale
        self.carried = carried
        self.isEmptyTransition = isEmptyTransition
    }
}

/// Building a plan.
public enum MorphPlanner {
    /// The plan for one change of value.
    public static func plan(_ input: MorphPlanInput) -> MorphPlan {
        var animations = leaving(input)
        animations.append(contentsOf: arrivingAndPersisting(input))

        return MorphPlan(
            durationMs: input.durationMs,
            curve: input.curve,
            lineCount: input.newLayout.lineCount,
            slideDistance: input.newLayout.slideDistance,
            segments: animations,
            container: container(input)
        )
    }

    /// The plan for a value appearing for the first time.
    ///
    /// Nothing moves and nothing fades. Upstream's initial render produces no
    /// animations and fires no callbacks, and that is not an optimisation:
    /// animating the first value in would mean every piece of morphing text on
    /// a screen flew in from nowhere the moment it appeared.
    public static func still(_ layout: MorphLayout, segments: [Segment]) -> MorphPlan {
        let kinds = kindsById(segments)
        let animations = layout.boxes.map { box in
            SegmentAnimation(
                id: box.id,
                string: stringsById(segments)[box.id] ?? "",
                kind: kinds[box.id] ?? nil,
                role: .persist,
                source: .new,
                box: box,
                from: .resting,
                to: .resting,
                fadeWindow: .whole,
                scaleOrigin: box.centre
            )
        }
        return MorphPlan.still(
            segments: animations,
            width: layout.width,
            height: layout.height,
            lineCount: layout.lineCount,
            slideDistance: layout.slideDistance
        )
    }
}

// MARK: - the container, and the odds and ends

extension MorphPlanner {
    static func container(_ input: MorphPlanInput) -> ContainerAnimation {
        ContainerAnimation(
            width: ContainerAxis(
                from: input.oldLayout.width, to: input.newLayout.width, curve: input.curve
            ),
            height: ContainerAxis(
                from: input.oldLayout.height, to: input.newLayout.height, curve: input.curve
            ),
            holdsOldSize: input.isEmptyTransition
        )
    }

    /// What a segment already on screen was doing, or nothing.
    static func carriedStart(_ input: MorphPlanInput, id: String) -> SegmentState {
        input.carried[id] ?? .resting
    }

    /// The centre each run shares, restated for every member of it.
    static func centres(of runs: [[Int]], in boxes: [SegmentBox]) -> [Int: MorphPoint] {
        var out: [Int: MorphPoint] = [:]
        for run in runs {
            let members = run.map { boxes[$0] }
            guard let first = members.first else { continue }
            var left = first.x
            var right = first.x + first.width
            var top = first.y
            var bottom = first.y + first.height
            for box in members.dropFirst() {
                left = min(left, box.x)
                right = max(right, box.x + box.width)
                top = min(top, box.y)
                bottom = max(bottom, box.y + box.height)
            }
            let centre = MorphPoint(x: (left + right) / 2, y: (top + bottom) / 2)
            for index in run {
                out[index] = centre
            }
        }
        return out
    }

    static func stringsById(_ segments: [Segment]) -> [String: String] {
        var out: [String: String] = [:]
        out.reserveCapacity(segments.count)
        for segment in segments {
            out[segment.id] = segment.string
        }
        return out
    }

    static func kindsById(_ segments: [Segment]) -> [String: SegmentKind?] {
        var out: [String: SegmentKind?] = [:]
        out.reserveCapacity(segments.count)
        for segment in segments {
            out[segment.id] = segment.kind
        }
        return out
    }
}
