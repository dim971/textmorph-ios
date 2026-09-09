import Foundation
import Testing
@testable import TextMorph

/// The spring solver, against the JavaScript original.
///
/// This suite holds the only tolerance anywhere in the fixtures, and it is
/// worth saying exactly what it is and why.
///
/// The position function goes through `exp`, `cos` and `sin`. V8 uses fdlibm
/// for those; Darwin's libm is a different implementation and is free to differ
/// in the last bit. It does: 4 of the 357 sampled positions differ, every one
/// of them by 1.11e-16. Swift has no `StrictMath`, so matching fdlibm exactly
/// would mean porting it, which is out of proportion to a difference no pixel
/// can show.
///
/// The bound is tied to one rather than to the value, and that is not
/// laziness. Every branch of the position function computes `1 - something`,
/// so the result inherits the absolute accuracy of a quantity near one however
/// small the result itself is: the observed differences are all half an ulp of
/// one, which on a result of 0.19 is four ulps of the result. Bounding by the
/// ulp of the value would therefore be the wrong shape as well as too tight.
///
/// So the position is compared to within the ulp of one, and the *duration* is
/// compared exactly. That is the split that matters. The duration is not a
/// cosmetic number: every opacity window in the library is a fraction of it,
/// and it is an integer produced by a threshold crossing inside an
/// accumulating loop, so a last-bit difference could in principle move it by a
/// millisecond and shift every fade. Across the whole parameter matrix,
/// including the near-critical values and the precision sweep, it does not move
/// at all. That is a measurement rather than a guarantee, which is why it is
/// asserted with no tolerance and why the matrix is as wide as it is.
@Suite("The spring, against upstream")
struct SpringGoldenTests {
    let goldens: Goldens

    init() throws {
        goldens = try Fixtures.load(Goldens.self, from: "goldens")
    }

    @Test("Stiffness, damping and mass resolve to the same frequency and ratio")
    func parameterisation() {
        var failures: [String] = []
        for testCase in goldens.spring {
            let omega0 = JsMath.sqrt(testCase.stiffness / testCase.mass)
            let zeta = testCase.damping / (2 * JsMath.sqrt(testCase.stiffness * testCase.mass))
            if omega0 != testCase.omega0 || zeta != testCase.zeta {
                failures.append("  \(describe(testCase)):"
                    + " expected omega0 \(testCase.omega0) zeta \(testCase.zeta),"
                    + " got \(omega0) and \(zeta)")
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("The settling duration, to the millisecond")
    func settlingDuration() {
        var failures: [String] = []
        for testCase in goldens.spring where testCase.deviates == nil {
            let actual = Spring.settlingDuration(
                omega0: testCase.omega0, zeta: testCase.zeta, precision: testCase.precision
            )
            if actual != testCase.upstreamDuration.double {
                failures.append("  \(describe(testCase)):"
                    + " expected \(testCase.upstreamDuration.double)ms, got \(actual)ms")
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("The position, sampled across the settling time, to within one ulp")
    func positions() {
        var failures: [String] = []
        var worstUlps = 0.0
        var differing = 0
        var compared = 0

        for testCase in goldens.spring {
            guard let samples = testCase.samples else { continue }
            let duration = testCase.upstreamDuration.double
            for (index, expected) in samples.enumerated() {
                let t = (Double(index) / 20) * (duration / 1000)
                let actual = Spring.position(
                    at: t, omega0: testCase.omega0, zeta: testCase.zeta
                )
                compared += 1
                guard actual != expected else { continue }
                differing += 1

                // The position is `1 - something` in every branch, so its
                // absolute accuracy is that of a quantity near one.
                let ulps = abs(actual - expected) / 1.0.ulp
                worstUlps = max(worstUlps, ulps)
                if ulps > 1 {
                    failures.append("  \(describe(testCase)) at t=\(t):"
                        + " expected \(expected), got \(actual)"
                        + " (\(ulps) ulps of one, which is more than the one this allows)")
                }
            }
        }

        #expect(failures.isEmpty, report(failures))
        // Recorded so a toolchain that makes the agreement worse is visible
        // here rather than only in a wider tolerance.
        #expect(worstUlps <= 1, Comment(rawValue: "worst difference \(worstUlps) ulps of one"))
        #expect(
            differing <= compared / 50,
            Comment(rawValue: "\(differing) of \(compared) positions differ at all,"
                + " which is more of libm than expected")
        )
    }

    @Test("The default spring is the one upstream ships")
    func defaultSpring() {
        let resolved = Spring.resolve(SpringParameters())
        // Measured, not derived: the exponential envelope suggests about
        // 1410ms, and the threshold crossing actually lands at 1271.
        #expect(resolved.durationMs == 1271)
        #expect(resolved.curve == .spring(omega0: 10, zeta: 0.5, durationMs: 1271))
    }

    @Test("Critical damping works here, where upstream returns NaN and minus zero")
    func criticalDamping() throws {
        let broken = try #require(
            goldens.spring.first { $0.deviates != nil },
            "the fixture should record upstream's broken critical case"
        )
        // What upstream does, for the record.
        #expect(broken.upstreamDuration == .negativeZero)
        #expect(broken.zeta == 1)

        // What this port does instead: the analytic critical solution, which
        // rises monotonically to its target and settles in a sane time.
        let resolved = Spring.resolve(SpringParameters(
            stiffness: broken.stiffness,
            damping: broken.damping,
            mass: broken.mass,
            precision: broken.precision
        ))
        #expect(resolved.durationMs > 100)
        #expect(resolved.durationMs < 10000)

        var previous = -1.0
        for step in 0 ... 40 {
            let t = (Double(step) / 40) * (resolved.durationMs / 1000)
            let value = Spring.position(at: t, omega0: broken.omega0, zeta: broken.zeta)
            #expect(value.isFinite, "the critical branch must not produce NaN")
            #expect(value >= previous, "critical damping does not overshoot or ring")
            #expect(value <= 1)
            previous = value
        }
        #expect(previous > 1 - broken.precision)
    }

    @Test("A spring ignores the morph's own duration, and a bezier honours it")
    func easeResolution() {
        let spring = TextMorphEase.spring().resolve(fallbackDuration: 400)
        #expect(spring.durationMs == 1271)

        let bezier = TextMorphEase.default.resolve(fallbackDuration: 400)
        #expect(bezier.durationMs == 400)
        #expect(bezier.curve == .bezier(.default))
    }

    private func describe(_ testCase: GoldenSpringCase) -> String {
        "stiffness \(testCase.stiffness) damping \(testCase.damping)"
            + " mass \(testCase.mass) precision \(testCase.precision)"
    }

    private func report(_ failures: [String]) -> Comment {
        Comment(rawValue: "\(failures.count) disagree:\n"
            + failures.prefix(12).joined(separator: "\n"))
    }
}
