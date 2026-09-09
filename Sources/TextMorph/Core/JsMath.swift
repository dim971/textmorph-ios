// The arithmetic upstream does, routed through one place.
//
// This looks like an indirection that earns nothing, and on this platform it
// currently earns nothing: Darwin's libm agrees with V8 on every value the
// fixtures cover. It exists for two reasons.
//
// The first is that agreement is a measurement, not a guarantee. V8 uses
// fdlibm for `pow`, `exp`, `sin`, `cos` and `log`, and a platform libm is free
// to differ by an ulp. One ulp is invisible in a position and decisive in
// `Spring.settlingDuration`, which returns an integer produced by a threshold
// crossing inside an accumulating loop: a last-bit difference moves the
// duration by a millisecond, and every fade window in the library is a
// fraction of that duration. If a fixture ever disagrees, this is the file to
// change, and changing it here changes it once.
//
// The second is the Android twin, where the difference is not hypothetical.
// `java.lang.Math` is allowed to be faster than exact, and the reference
// project already had to force `StrictMath`, which is fdlibm, to match. Naming
// the calls on both sides keeps that decision visible rather than buried in an
// expression.

import Foundation

/// The subset of JavaScript's `Math` that this port uses.
enum JsMath {
    /// `Math.E`
    static let e = M_E

    /// `Math.exp`
    static func exp(_ x: Double) -> Double { Foundation.exp(x) }

    /// `Math.sin`
    static func sin(_ x: Double) -> Double { Foundation.sin(x) }

    /// `Math.cos`
    static func cos(_ x: Double) -> Double { Foundation.cos(x) }

    /// `Math.sqrt`
    static func sqrt(_ x: Double) -> Double { Foundation.sqrt(x) }

    /// `Math.pow`
    static func pow(_ x: Double, _ y: Double) -> Double { Foundation.pow(x, y) }

    /// `Math.ceil`
    static func ceil(_ x: Double) -> Double { Foundation.ceil(x) }
}
