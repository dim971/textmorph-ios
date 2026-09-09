import Foundation
import Testing
@testable import TextMorph

/// The bezier and the carried curve, against the JavaScript original.
///
/// These are compared without tolerance. A bezier is multiplies and adds, so
/// there is no reason for two platforms to disagree, and the carried curve adds
/// one `pow`. If a value ever differs, the honest answer is to find out why
/// rather than to widen the comparison.
@Suite("Easing, against upstream")
struct EasingGoldenTests {
    let goldens: Goldens

    init() throws {
        goldens = try Fixtures.load(Goldens.self, from: "goldens")
    }

    @Test("Every bezier, sampled at 101 points")
    func bezierSamples() {
        var failures: [String] = []
        for testCase in goldens.easing.bezier {
            let curve = CubicBezier(
                testCase.points[0], testCase.points[1], testCase.points[2], testCase.points[3]
            )
            for (index, expected) in testCase.samples.enumerated() {
                let t = Double(index) / Double(testCase.samples.count - 1)
                let actual = curve.value(at: t)
                if actual != expected {
                    failures.append(
                        "  \(testCase.name) at t=\(t): expected \(expected), got \(actual)"
                            + " (difference \(actual - expected))"
                    )
                }
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("The slope, which decides how much momentum an interrupted morph carries")
    func slopes() {
        var failures: [String] = []
        for testCase in goldens.easing.bezier {
            let curve = EasingCurve.bezier(CubicBezier(
                testCase.points[0], testCase.points[1], testCase.points[2], testCase.points[3]
            ))
            // Both ends and the middle: the slope at nought is what `carry`
            // reads, and the slope at one is where the forward difference has
            // to clamp rather than step past the curve.
            let expectations: [Double: Double] = [
                0: testCase.slopeAtZero,
                0.5: testCase.slopeAtHalf,
                1: testCase.slopeAtOne
            ]
            for (t, expected) in expectations.sorted(by: { $0.key < $1.key }) {
                let actual = Easing.slope(of: curve, at: t)
                if actual != expected {
                    failures.append("  \(testCase.name) slope at \(t):"
                        + " expected \(expected), got \(actual)")
                }
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("The default curve starts fast, which is why most velocities carry nothing")
    func defaultCurveStartsFast() {
        let slope = Easing.slope(of: .bezier(.default), at: 0)
        #expect(slope > 5)
        // Momentum is only ever added. A box travelling slower than the curve
        // already leaves gets the curve unchanged.
        #expect(Easing.carry(.bezier(.default), normalisedVelocity: 3).k == 0)
        #expect(Easing.carry(.bezier(.default), normalisedVelocity: slope + 1).k > 0)
    }

    @Test("A velocity that could not be measured carries nothing")
    func unmeasurableVelocity() {
        // Upstream relies on NaN propagating through Math.min and Math.max,
        // which Swift's do not do, so this is the guard that stands in for it.
        for velocity in [Double.nan, .infinity, -.infinity] {
            let carried = Easing.carry(.bezier(.default), normalisedVelocity: velocity)
            #expect(carried.k == 0)
            #expect(carried.curve == .bezier(.default))
        }
    }

    @Test("Every carried curve, sampled at 21 points")
    func carrySamples() {
        let bases: [String: CubicBezier] = [
            "default": .default, "linear": .linear, "ease": .ease
        ]
        var failures: [String] = []
        for testCase in goldens.easing.carry {
            guard let base = bases[testCase.base] else {
                failures.append("  unknown base curve \(testCase.base)")
                continue
            }
            let carried = Easing.carry(.bezier(base), normalisedVelocity: testCase.velocity)
            if carried.k != testCase.k.double {
                failures.append("  \(testCase.base) at velocity \(testCase.velocity):"
                    + " k expected \(testCase.k.double), got \(carried.k)")
                continue
            }
            for (index, expected) in testCase.samples.enumerated() {
                let t = Double(index) / Double(testCase.samples.count - 1)
                let actual = carried.curve.value(at: t)
                if actual != expected {
                    failures.append(
                        "  \(testCase.base) velocity \(testCase.velocity) at t=\(t):"
                            + " expected \(expected), got \(actual)"
                            + " (difference \(actual - expected))"
                    )
                }
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    private func report(_ failures: [String]) -> Comment {
        Comment(rawValue: "\(failures.count) disagree:\n"
            + failures.prefix(12).joined(separator: "\n"))
    }
}
