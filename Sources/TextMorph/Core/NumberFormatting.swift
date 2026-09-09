// A port of the one line of torph that turns a numeric value into a string,
// from packages/torph/src/lib/text-morph/index.ts:
//
//   value.toLocaleString(locale, {
//     minimumFractionDigits: decimals,
//     maximumFractionDigits: decimals,
//   })

import Foundation

/// Turning a numeric value into the string a morph is run on.
public enum NumberFormatting {
    /// Intl's default when no fraction length is asked for: at least none, at
    /// most three.
    ///
    /// Passing `undefined` for both options in JavaScript is not the same as
    /// passing nothing at all in Swift, so the default is written out. Three is
    /// easy to mistake for an arbitrary choice; it is what `Intl.NumberFormat`
    /// does, and a value formatted with four decimals here would morph
    /// differently from the same value on the web.
    public static let defaultFractionDigits = 0 ... 3

    /// Formats a numeric value the way upstream does.
    ///
    /// `decimals` sets both the minimum and the maximum fraction length, so
    /// `decimals: 2` pads as well as truncates: 1.5 formats as `1.50`.
    ///
    /// Halves round away from zero. That is `halfExpand`, which is what
    /// `Intl.NumberFormat` uses and what ICU calls `HALF_UP`, and it is not the
    /// same as rounding towards positive infinity: it takes -1.5 to -2 rather
    /// than to -1. The fixtures pin it for negative values rather than trusting
    /// the name.
    public static func format(
        _ value: Double,
        decimals: Int? = nil,
        locale: Locale = defaultMorphLocale
    ) -> String {
        let precision: NumberFormatStyleConfiguration.Precision = if let decimals {
            .fractionLength(decimals)
        } else {
            .fractionLength(defaultFractionDigits)
        }

        return value.formatted(
            .number
                .locale(locale)
                .precision(precision)
                .rounded(rule: .toNearestOrAwayFromZero)
        )
    }
}
