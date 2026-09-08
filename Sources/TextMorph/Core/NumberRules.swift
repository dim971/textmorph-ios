// A port of the classification half of torph's
// packages/torph/src/lib/text-morph/utils/number.ts.

import Foundation

/// Which characters a quantity is allowed to be made of, and how they are read.
///
/// The sets are upstream's, character for character, including the four exotic
/// spaces some locales group with. Widening any of them changes what counts as
/// a number, and therefore what morphs by place value rather than by character.
enum NumberRules {
    /// Separators that can appear *between* digits without ending the number.
    static let coreSeparators: Set<Character> = [
        ".", ",", "'", "\u{00A0}", "\u{202F}", "\u{2009}", "\u{2007}"
    ]

    /// Characters allowed before the first digit.
    static let prefixCharacters: Set<Character> = ["+", "-", "\u{2212}", "(", "#"]

    /// Characters allowed after the last digit.
    static let suffixCharacters: Set<Character> = [
        "%", ".", ",", "!", "?", ":", ";", ")", "\"", "'", "\u{201D}", "\u{2019}"
    ]

    /// An ASCII decimal digit, which is the only thing upstream counts as one.
    ///
    /// Upstream writes `char >= "0" && char <= "9"`, a comparison of UTF-16
    /// code units. Swift's `Character` comparison is a Unicode collation and
    /// would answer differently, so the test goes through the scalar value.
    static func isDigit(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first else { return false }
        return scalar.value >= 0x30 && scalar.value <= 0x39
    }

    /// Whether a value holds a digit anywhere.
    static func hasDigit(_ value: String) -> Bool {
        value.contains(where: isDigit)
    }

    /// A currency symbol, general category Sc, which upstream matches with `\p{Sc}`.
    static func isCurrency(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return scalar.properties.generalCategory == .currencySymbol
    }

    /// What is left of a token once its digits and separators go: `$`, `%`, `()`.
    ///
    /// Two tokens with the same skeleton are the same shape of quantity, which
    /// is what lets the diff pair `$1,204` with `$1,318` in preference to
    /// anything they happen to share characters with.
    static func numericSkeleton(_ word: String) -> String {
        String(word.filter { !isDigit($0) && !coreSeparators.contains($0) })
    }

    /// Whether a token is a quantity.
    ///
    /// Strict on purpose, and on by default: merely holding a digit is not
    /// enough, or `COVID-19` and `2024-01-01` would morph by place value.
    /// Affixes are trimmed from both ends, and what is left must start and end
    /// with a digit and hold nothing but digits and core separators.
    static func isNumericWord(_ word: String) -> Bool {
        let characters = Array(word)
        var start = 0
        var end = characters.count

        while start < end, isAffix(characters[start], prefixCharacters) {
            start += 1
        }
        while end > start, isAffix(characters[end - 1], suffixCharacters) {
            end -= 1
        }

        if start >= end { return false }
        if !isDigit(characters[start]) || !isDigit(characters[end - 1]) { return false }

        for index in start ..< end {
            let character = characters[index]
            if !isDigit(character), !coreSeparators.contains(character) { return false }
        }

        return true
    }

    /// Whether a character of a numeric word is a digit or one of the symbols
    /// that travel with the places they belong to.
    static func classifyKind(_ character: Character) -> SegmentKind {
        isDigit(character) ? .digit : .symbol
    }

    private static func isAffix(_ character: Character, _ set: Set<Character>) -> Bool {
        set.contains(character) || isCurrency(character)
    }
}

// MARK: - the locale's decimal separator

extension NumberRules {
    /// The locale's decimal separator, the pivot every place alignment is
    /// measured from.
    ///
    /// Upstream reads it out of `Intl.NumberFormat(locale).formatToParts(1.1)`
    /// and memoises it, because constructing an `Intl.NumberFormat` is
    /// expensive. `Locale.decimalSeparator` is the same value from the same
    /// CLDR data and is cheap, and it is read once per morph rather than once
    /// per segment, so there is no cache here to keep in step with anything.
    static func decimalSeparator(for locale: Locale) -> Character {
        guard let separator = locale.decimalSeparator, separator.count == 1 else { return "." }
        return Character(separator)
    }
}
