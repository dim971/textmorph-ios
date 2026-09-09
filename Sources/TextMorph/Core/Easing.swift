// A port of torph's packages/torph/src/lib/utils/easing.ts, and of the `carry`
// half of packages/torph/src/lib/utils/animate.ts.
//
// The CSS-facing parts of easing.ts are deliberately not ported: `parseEasing`
// reads a curve back out of a string, `linearEasing` and `fillStops` understand
// the `linear()` syntax, and `sampleEasing` writes a curve back into one. This
// API is typed, so a curve never becomes a string, and this port drives its own
// clock, so a curve is never sampled into a stylesheet. What is left is the
// evaluation, which is the part the engine actually needs.

import Foundation

/// A cubic bezier easing, in CSS's parameterisation.
///
/// The first and last control points are fixed at (0, 0) and (1, 1), so a curve
/// is the two in between, exactly as `cubic-bezier()` takes them.
public struct CubicBezier: Hashable, Sendable {
    /// The first control point.
    public let x1: Double, y1: Double
    /// The second control point.
    public let x2: Double, y2: Double

    /// Creates a curve from its two free control points.
    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// The curve torph uses unless told otherwise: a long, decelerating ease
    /// out, which is what makes a morph read as one gesture rather than as a
    /// set of characters each doing its own thing.
    public static let `default` = CubicBezier(0.19, 1, 0.22, 1)

    /// CSS `linear`.
    public static let linear = CubicBezier(0, 0, 1, 1)
    /// CSS `ease`.
    public static let ease = CubicBezier(0.25, 0.1, 0.25, 1)
    /// CSS `ease-in`.
    public static let easeIn = CubicBezier(0.42, 0, 1, 1)
    /// CSS `ease-out`.
    public static let easeOut = CubicBezier(0, 0, 0.58, 1)
    /// CSS `ease-in-out`.
    public static let easeInOut = CubicBezier(0.42, 0, 0.58, 1)

    /// The curve's value at a normalised time.
    ///
    /// Twenty-four steps of bisection on the x axis, then the y axis read at
    /// the midpoint. Upstream's count, kept: it is well past the precision of a
    /// pixel and it costs nothing, and changing it would move every sample the
    /// fixtures record. There is no transcendental arithmetic in here, only
    /// multiplies and adds, so the result is identical on every platform.
    public func value(at t: Double) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }

        var low = 0.0
        var high = 1.0
        for _ in 0 ..< 24 {
            let mid = (low + high) / 2
            if Self.axis(x1, x2, mid) < t { low = mid } else { high = mid }
        }
        return Self.axis(y1, y2, (low + high) / 2)
    }

    /// One axis of the curve, with its endpoints fixed at 0 and 1.
    private static func axis(_ p1: Double, _ p2: Double, _ t: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t
    }
}

/// A curve the engine can sample, whatever it was built from.
///
/// A value type rather than a closure, so a plan is comparable, hashable and
/// cheap to carry across a frame.
public enum EasingCurve: Hashable, Sendable {
    /// A cubic bezier, as the author wrote it.
    case bezier(CubicBezier)

    /// A damped spring, evaluated from its own physics rather than sampled.
    ///
    /// `durationMs` is what `Spring` computed the settling time to be, and is
    /// what turns the spring's own seconds into the normalised time every other
    /// curve here speaks.
    case spring(omega0: Double, zeta: Double, durationMs: Double)

    /// The author's curve, leaving at the speed the box is already travelling.
    indirect case carried(base: EasingCurve, k: Double, bump: Double)

    /// The curve's value at a normalised time.
    public func value(at t: Double) -> Double {
        switch self {
        case let .bezier(bezier):
            return bezier.value(at: t)

        case let .spring(omega0, zeta, durationMs):
            return Spring.position(at: t * durationMs / 1000, omega0: omega0, zeta: zeta)

        case let .carried(base, k, bump):
            if t >= 1 { return 1 }
            return base.value(at: t) + k * t * JsMath.pow(1 - t, bump)
        }
    }
}

/// The slope of a curve, and the momentum an interrupted one carries into the
/// next.
public enum Easing {
    /// The step the forward difference uses. Upstream's, kept: a different step
    /// gives a different slope, and the slope decides how much momentum is
    /// carried.
    static let slopeStep = 1e-4

    /// Progress per unit of normalised time.
    ///
    /// Forward rather than centred, so a knot reports the segment ahead of it
    /// rather than an average of the two either side.
    public static func slope(of curve: EasingCurve, at t: Double) -> Double {
        let clamped = min(max(t, 0), 1 - slopeStep)
        return (curve.value(at: clamped + slopeStep) - curve.value(at: clamped)) / slopeStep
    }

    /// A curve that starts at the speed the box is already travelling.
    ///
    /// A morph arriving mid-transition restarts the curve at zero, so a fast
    /// run of them only ever plays each curve's opening sliver and the box
    /// crawls while the value races ahead. Adding `k * t * (1 - t)^bump` fixes
    /// the start slope to the carried velocity without moving either endpoint,
    /// and `bump` narrows as `k` grows so the peak stays inside the overshoot
    /// allowance.
    ///
    /// Momentum is only ever added, never subtracted. A curve that starts
    /// faster than the box was moving is the author's business, and slowing it
    /// to match would make a value that had settled start sluggishly.
    public static func carry(
        _ base: EasingCurve, normalisedVelocity velocity: Double
    ) -> (curve: EasingCurve, k: Double) {
        // Upstream leans on JavaScript arithmetic here: `Math.max(0, NaN)` is
        // NaN and `NaN > 0` is false, so a velocity that could not be measured
        // falls through to the base curve. Swift's `min` and `max` return the
        // other operand instead of propagating, so the guard is explicit.
        guard velocity.isFinite else { return (base, 0) }

        let k = max(0, min(MorphTiming.carryMaximum, velocity) - slope(of: base, at: 0))
        guard k > 0 else { return (base, 0) }

        let bump = max(
            3,
            JsMath.ceil(k / (JsMath.e * MorphTiming.carryOvershoot)) - 1
        )
        return (.carried(base: base, k: k, bump: bump), k)
    }
}
