// What a morph does, as a pure function of elapsed time.
//
// This has no upstream counterpart, because upstream hands its work to the web
// animation API: it writes keyframes and lets the browser interpolate them.
// This port drives its own clock, so it has to say what every segment looks
// like at any moment, and that is what a plan is.
//
// It is also the parity contract. `frame(atElapsed:)` is the one function both
// ports sample, so if the two agree about a plan and agree about that function,
// they agree about the morph. Everything above it is layout and everything
// below it is drawing.

/// Why a segment is moving, which decides how it moves.
public enum SegmentRole: Hashable, Sendable {
    /// It survived the change and is being carried to its new place.
    case persist
    /// It is new, and arrives from near whatever survived beside it.
    case enter
    /// It is going, and recedes towards whatever is taking its place.
    case exit

    /// It is one of at least six adjacent segments all arriving together, so
    /// the run grows from its own centre instead of each segment travelling.
    case groupEnter
    /// The same run leaving, collapsing towards its own centre.
    case groupExit

    /// A character of a number that survived, whose slot takes the
    /// displacement.
    case numberPersist
    /// A character of a number that arrived, sliding in along the block axis.
    case numberEnter
    /// A character of a number that is going, sliding out along the block axis.
    case numberExit

    /// Whether this role slides inside a clipped slot rather than moving as a
    /// whole.
    public var isNumber: Bool {
        self == .numberPersist || self == .numberEnter || self == .numberExit
    }

    /// Whether this role scales about a shared centre rather than its own.
    public var isGroup: Bool {
        self == .groupEnter || self == .groupExit
    }

    /// Whether the segment is on its way out, and so should be dropped once its
    /// fade closes.
    public var isLeaving: Bool {
        self == .exit || self == .groupExit || self == .numberExit
    }
}

/// Which layout a segment's resting box and glyphs come from.
///
/// A segment that is leaving has no place in the new value, so it is drawn from
/// where it was; everything else is drawn from where it is going.
public enum LayoutSource: Hashable, Sendable {
    case old
    case new
}

/// Everything about a segment that moves.
public struct SegmentState: Hashable, Sendable {
    /// Displacement from the segment's resting box.
    public var dx: Double
    public var dy: Double
    /// About the segment's own centre, or a run's shared centre for a group.
    public var scale: Double
    public var opacity: Double
    /// The inner slide of a number's character inside its slot, which is
    /// separate from the slot's own displacement so a digit can cross a whole
    /// line box without the next morph measuring it as moved.
    public var moverDy: Double

    /// Creates a state, defaulting to at rest and fully opaque.
    public init(
        dx: Double = 0, dy: Double = 0, scale: Double = 1,
        opacity: Double = 1, moverDy: Double = 0
    ) {
        self.dx = dx
        self.dy = dy
        self.scale = scale
        self.opacity = opacity
        self.moverDy = moverDy
    }

    /// At rest.
    public static let resting = SegmentState()
}

/// When something happens, as a share of the morph.
///
/// Opacity is the only thing that runs on a window rather than the whole
/// duration, and it always runs linearly inside it. Upstream animates the
/// transform with the author's curve and the opacity with `linear` over a
/// fraction of the duration, which is exactly why the clock this samples has to
/// stay linear: if the clock itself were eased, recovering linear time inside
/// the window would need the curve's inverse.
public struct TimeWindow: Hashable, Sendable {
    /// A share of the duration, from zero.
    public var start: Double
    /// A share of the duration, to one.
    public var end: Double

    /// Creates a window.
    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    /// A window covering the whole morph.
    public static let whole = TimeWindow(start: 0, end: 1)

    /// A window of `fraction` of the duration, starting after `delay`.
    public static func fraction(_ fraction: Double, after delay: Double = 0) -> TimeWindow {
        TimeWindow(start: delay, end: delay + fraction)
    }

    /// How far through the window a given elapsed time is, linearly.
    func progress(atElapsed elapsed: Double, duration: Double) -> Double {
        let startMs = start * duration
        let endMs = end * duration
        if elapsed <= startMs { return 0 }
        if elapsed >= endMs { return 1 }
        let span = endMs - startMs
        return span <= 0 ? 1 : (elapsed - startMs) / span
    }
}

/// One segment of a morph.
public struct SegmentAnimation: Sendable {
    /// The segment's identity, which is what makes it the same segment as the
    /// one in the last morph.
    public let id: String
    /// The text it draws.
    public let string: String
    /// Set for a character of a number.
    public let kind: SegmentKind?
    /// Why it is moving.
    public let role: SegmentRole
    /// Which layout to draw it from.
    public let source: LayoutSource
    /// Where it rests in that layout.
    public let box: SegmentBox
    /// Where it starts.
    public let from: SegmentState
    /// Where it ends.
    public let to: SegmentState
    /// When its opacity changes.
    public let fadeWindow: TimeWindow
    /// What its scale is measured about: its own centre, or a run's.
    public let scaleOrigin: MorphPoint
}

/// One axis of the container's own size.
///
/// The two axes are independent, each with its own curve and its own place in
/// the clock, because upstream animates them separately and for a reason: a
/// value updated faster than the morph settles restarts the curve every frame,
/// and a curve that is slow to leave never gets past its opening sliver. So an
/// axis whose target has not moved resumes at the phase it had reached instead
/// of starting over, which is what the offset carries.
public struct ContainerAxis: Hashable, Sendable {
    public var from: Double
    public var to: Double
    public var curve: EasingCurve
    /// How far into its own curve this axis already was when the plan began.
    public var clockOffsetMs: Double

    /// Creates an axis.
    public init(from: Double, to: Double, curve: EasingCurve, clockOffsetMs: Double = 0) {
        self.from = from
        self.to = to
        self.curve = curve
        self.clockOffsetMs = clockOffsetMs
    }

    /// The axis's value at a given elapsed time.
    func value(atElapsed elapsed: Double, duration: Double) -> Double {
        guard duration > 0 else { return to }
        let t = min(max((elapsed + clockOffsetMs) / duration, 0), 1)
        return from + (to - from) * curve.value(at: t)
    }
}

/// The container's own size, over the morph.
public struct ContainerAnimation: Sendable {
    public var width: ContainerAxis
    public var height: ContainerAxis

    /// Set when the value emptied out.
    ///
    /// Upstream holds the old box on a timer rather than animating it, because
    /// a container collapsing to nothing takes the line box with it and the
    /// segments still leaving would jump.
    public var holdsOldSize: Bool

    /// Creates a container animation.
    public init(width: ContainerAxis, height: ContainerAxis, holdsOldSize: Bool = false) {
        self.width = width
        self.height = height
        self.holdsOldSize = holdsOldSize
    }
}

/// What every segment looks like at one moment.
public struct MorphFrame: Sendable {
    /// One state per segment of the plan, in the plan's own order.
    public let states: [SegmentState]
    /// The container's width at this moment.
    public let width: Double
    /// The container's height at this moment.
    public let height: Double
    /// Whether the morph has run its course.
    public let isFinished: Bool
}

/// A morph, as a function of elapsed time.
public struct MorphPlan: Sendable {
    /// How long the whole morph takes, in milliseconds.
    public let durationMs: Double
    /// The curve every displacement and scale follows.
    public let curve: EasingCurve
    /// How far past its target the curve goes, as a share of the travel.
    ///
    /// Zero for a monotone bezier; about sixteen percent for the default
    /// spring. It inflates the surface a morph is allowed to draw on, because a
    /// glyph clipped at the peak of its bounce is a bug that only appears with
    /// springs.
    public let overshoot: Double
    /// How many lines the new value has.
    public let lineCount: Int
    /// How far a digit slides when it enters or leaves.
    public let slideDistance: Double
    /// Every segment that is drawn, in the order it should be drawn.
    public let segments: [SegmentAnimation]
    /// The container's own size.
    public let container: ContainerAnimation

    /// Creates a plan.
    public init(
        durationMs: Double,
        curve: EasingCurve,
        lineCount: Int,
        slideDistance: Double,
        segments: [SegmentAnimation],
        container: ContainerAnimation
    ) {
        self.durationMs = durationMs
        self.curve = curve
        self.lineCount = lineCount
        self.slideDistance = slideDistance
        self.segments = segments
        self.container = container
        overshoot = Self.overshoot(of: curve)
    }

    /// The state of every segment, and the container, at one moment.
    ///
    /// Pure and total: any elapsed time answers, including a negative one and
    /// one past the end. Transforms follow the curve, opacity follows raw
    /// linear time inside its own window, and the container follows its own
    /// curve from its own place in the clock.
    public func frame(atElapsed elapsed: Double) -> MorphFrame {
        let t = durationMs > 0 ? min(max(elapsed / durationMs, 0), 1) : 1
        let eased = curve.value(at: t)

        var states: [SegmentState] = []
        states.reserveCapacity(segments.count)
        for animation in segments {
            let fade = animation.fadeWindow.progress(atElapsed: elapsed, duration: durationMs)
            states.append(SegmentState(
                dx: interpolate(animation.from.dx, animation.to.dx, eased),
                dy: interpolate(animation.from.dy, animation.to.dy, eased),
                scale: interpolate(animation.from.scale, animation.to.scale, eased),
                opacity: interpolate(animation.from.opacity, animation.to.opacity, fade),
                moverDy: interpolate(animation.from.moverDy, animation.to.moverDy, eased)
            ))
        }

        return MorphFrame(
            states: states,
            width: container.holdsOldSize
                ? container.width.from
                : container.width.value(atElapsed: elapsed, duration: durationMs),
            height: container.holdsOldSize
                ? container.height.from
                : container.height.value(atElapsed: elapsed, duration: durationMs),
            isFinished: t >= 1
        )
    }

    /// A plan that does nothing, for the first render of a value.
    ///
    /// Upstream's initial render produces no animations and fires no callbacks,
    /// which is not an optimisation: animating the first value in would mean
    /// every list of morphing text flew in from nowhere on appear.
    public static func still(
        segments: [SegmentAnimation], width: Double, height: Double, lineCount: Int,
        slideDistance: Double
    ) -> MorphPlan {
        let curve = EasingCurve.bezier(.linear)
        return MorphPlan(
            durationMs: 0,
            curve: curve,
            lineCount: lineCount,
            slideDistance: slideDistance,
            segments: segments,
            container: ContainerAnimation(
                width: ContainerAxis(from: width, to: width, curve: curve),
                height: ContainerAxis(from: height, to: height, curve: curve)
            )
        )
    }

    private func interpolate(_ from: Double, _ to: Double, _ progress: Double) -> Double {
        from == to ? from : from + (to - from) * progress
    }

    /// How far past one the curve reaches, sampled once when the plan is built.
    ///
    /// Sampled rather than derived: a spring's peak has a closed form, but a
    /// carried bezier's does not, and one sweep of a few dozen points at plan
    /// time is cheaper than being wrong about it every frame.
    private static func overshoot(of curve: EasingCurve) -> Double {
        var peak = 1.0
        for step in 0 ... 64 {
            peak = max(peak, curve.value(at: Double(step) / 64))
        }
        return peak - 1
    }
}
