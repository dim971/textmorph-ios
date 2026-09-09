// A port of torph's packages/torph/src/lib/utils/spring.ts.
//
// One thing upstream does here is not ported, and one thing it does is fixed.
//
// Not ported: upstream turns the spring into a sampled CSS `linear()` string,
// because the web animation it hands the morph to only speaks stylesheets.
// This port drives its own clock, so it evaluates the physics directly and
// there is nothing to sample.
//
// Fixed: at a damping ratio of exactly one, upstream's overdamped branch
// divides by zero. See `position(at:omega0:zeta:)`.

/// A spring, as an author describes one.
public struct SpringParameters: Hashable, Sendable {
    /// How hard the spring pulls. Upstream's default.
    public var stiffness: Double
    /// How much the motion is resisted. Upstream's default.
    public var damping: Double
    /// What is being moved. Upstream's default.
    public var mass: Double
    /// How close to its target the spring has to get before it is called
    /// settled, which is what decides the duration.
    public var precision: Double

    /// Creates spring parameters, defaulting to upstream's.
    public init(
        stiffness: Double = 100,
        damping: Double = 10,
        mass: Double = 1,
        precision: Double = 0.001
    ) {
        self.stiffness = stiffness
        self.damping = damping
        self.mass = mass
        self.precision = precision
    }
}

/// Solving a damped spring, and asking how long it takes to settle.
public enum Spring {
    /// A damping ratio this close to one is critical, and takes the branch
    /// written for it. The window is tight because it only has to catch the
    /// values where the overdamped form loses its precision, not to widen the
    /// critical case into a range.
    static let criticalEpsilon = 1e-12

    /// The step the settling search walks in, in seconds, and the longest it
    /// will look. Upstream's, and the loop accumulates rather than multiplying:
    /// see `settlingDuration`.
    static let searchStep = 0.001
    static let searchLimit = 10.0
    /// How long the spring has to stay inside `precision` before it counts as
    /// settled, in seconds.
    static let settledFor = 0.1

    /// Where a unit spring is at a given time, in seconds.
    ///
    /// Three branches, on the damping ratio. Underdamped, it overshoots and
    /// rings; critically damped, it arrives as fast as it can without
    /// overshooting; overdamped, it crawls in.
    ///
    /// The critical branch is not upstream's. Upstream has two branches and
    /// sends the critical case to the overdamped one, where `zeta == 1` makes
    /// the two roots equal, their difference zero, and the division by it
    /// infinite: the function returns NaN for every time. That is not a
    /// rounding problem, it is the whole option being broken, and because
    /// `NaN > precision` is false, `settlingDuration` then concludes the spring
    /// settled before it started and reports a duration of minus zero. So
    /// `damping: 20` at the default stiffness and mass, a perfectly ordinary
    /// thing to ask for, animates nothing at all.
    ///
    /// The port adds the analytic critical solution. Deviating identically on
    /// both platforms is the requirement here; following upstream would ship
    /// the same broken option twice.
    public static func position(at t: Double, omega0: Double, zeta: Double) -> Double {
        if zeta < 1 - criticalEpsilon {
            let omegaD = omega0 * JsMath.sqrt(1 - zeta * zeta)
            return 1 - JsMath.exp(-zeta * omega0 * t)
                * (JsMath.cos(omegaD * t) + ((zeta * omega0) / omegaD) * JsMath.sin(omegaD * t))
        }

        if zeta <= 1 + criticalEpsilon {
            return 1 - (1 + omega0 * t) * JsMath.exp(-omega0 * t)
        }

        let s = JsMath.sqrt(zeta * zeta - 1)
        let r1 = -omega0 * (zeta + s)
        let r2 = -omega0 * (zeta - s)
        let b = -r1 / (r2 - r1)
        let a = 1 - b
        return 1 - a * JsMath.exp(r1 * t) - b * JsMath.exp(r2 * t)
    }

    /// How long the spring takes to settle, in whole milliseconds.
    ///
    /// This number is load bearing well beyond the spring: every opacity window
    /// in the library is a fraction of the morph's duration, and for a spring
    /// the duration is whatever this returns. It is also not analytically
    /// predictable from the envelope, which is why no platform spring can stand
    /// in for it: the default parameters settle at 1271ms where the exponential
    /// envelope suggests about 1410.
    ///
    /// The loop accumulates `t` by adding the step rather than multiplying the
    /// index by it. Those are not the same sequence of doubles, and the answer
    /// is an integer produced by a threshold crossing, so rewriting it the
    /// tidier way changes the result.
    public static func settlingDuration(
        omega0: Double, zeta: Double, precision: Double
    ) -> Double {
        var settledSince = 0.0
        var t = 0.0
        while t < searchLimit {
            if abs(position(at: t, omega0: omega0, zeta: zeta) - 1) > precision {
                settledSince = 0
            } else {
                settledSince += searchStep
                if settledSince > settledFor {
                    return JsMath.ceil((t - settledSince + searchStep) * 1000)
                }
            }
            t += searchStep
        }

        return JsMath.ceil(searchLimit * 1000)
    }

    /// The curve and the duration a set of spring parameters resolves to.
    public static func resolve(_ parameters: SpringParameters) -> (curve: EasingCurve, durationMs: Double) {
        let omega0 = JsMath.sqrt(parameters.stiffness / parameters.mass)
        let zeta = parameters.damping / (2 * JsMath.sqrt(parameters.stiffness * parameters.mass))
        let durationMs = settlingDuration(
            omega0: omega0, zeta: zeta, precision: parameters.precision
        )
        return (.spring(omega0: omega0, zeta: zeta, durationMs: durationMs), durationMs)
    }
}

/// What the author asked a morph to move like.
public enum TextMorphEase: Hashable, Sendable {
    /// A cubic bezier, which honours the morph's `duration`.
    case bezier(CubicBezier)

    /// A spring, which settles on its own physics and ignores `duration`.
    case spring(SpringParameters)

    /// Upstream's default.
    public static let `default` = TextMorphEase.bezier(.default)

    /// A spring, spelled out.
    public static func spring(
        stiffness: Double = 100,
        damping: Double = 10,
        mass: Double = 1,
        precision: Double = 0.001
    ) -> TextMorphEase {
        .spring(SpringParameters(
            stiffness: stiffness, damping: damping, mass: mass, precision: precision
        ))
    }

    /// The curve to sample and how long to sample it for.
    ///
    /// `fallbackDuration` is the morph's own `duration`, used for a bezier and
    /// ignored for a spring, exactly as upstream's `resolveEase` does.
    public func resolve(fallbackDuration: Double) -> (curve: EasingCurve, durationMs: Double) {
        switch self {
        case let .bezier(bezier): (.bezier(bezier), fallbackDuration)
        case let .spring(parameters): Spring.resolve(parameters)
        }
    }
}
