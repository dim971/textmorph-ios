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
    ///
    /// Upstream's set, plus U+2019. That addition is a deliberate deviation and
    /// it is here because two ICU versions disagree about Swiss German: CLDR
    /// groups de-CH with U+0027 in one version and U+2019 in another, and which
    /// one a device produces depends on its OS. Without U+2019 in this set the
    /// same number would roll by place value on one OS version and morph
    /// character by character on the next, which is a worse outcome than
    /// widening the set by one character that is a group separator in CLDR
    /// either way.
    ///
    /// U+2019 is also an apostrophe, so it is already a trailing affix. That
    /// costs nothing: a token has to begin and end with a digit after trimming,
    /// so "don't" written with it is still not a quantity.
    static let coreSeparators: Set<Character> = [
        ".", ",", "'", "\u{2019}", "\u{00A0}", "\u{202F}", "\u{2009}", "\u{2007}"
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

    /// The same test on one UTF-16 code unit, which is upstream's own unit.
    static func isDigit(unit: UInt16) -> Bool {
        unit >= 0x30 && unit <= 0x39
    }

    /// Whether a value holds a digit anywhere.
    ///
    /// Over code units rather than over characters, because the two disagree:
    /// `"1"` followed by a combining acute is one `Character` that is not a
    /// digit, and two code units of which the first is. Upstream sees the code
    /// units, the Kotlin twin sees them for free, and this decides which
    /// pairing path the diff takes, so it is worth the explicit view.
    static func hasDigit(_ value: String) -> Bool {
        value.utf16.contains { isDigit(unit: $0) }
    }

    /// A currency symbol, general category Sc, which upstream matches with `\p{Sc}`.
    static func isCurrency(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return scalar.properties.generalCategory == .currencySymbol
    }

    /// The same test on one UTF-16 code unit.
    ///
    /// A lone surrogate is not a currency symbol, and that is the answer
    /// upstream and the Kotlin twin both give: an astral currency symbol such
    /// as U+1ECB0 is two code units, neither of which is in Sc, so it is not an
    /// affix. Deciding it on the whole scalar instead would make the two ports
    /// disagree about whether such a token is a quantity at all.
    static func isCurrency(unit: UInt16) -> Bool {
        guard let scalar = Unicode.Scalar(UInt32(unit)) else { return false }
        return scalar.properties.generalCategory == .currencySymbol
    }

    /// What is left of a token once its digits and separators go: `$`, `%`, `()`.
    ///
    /// Two tokens with the same skeleton are the same shape of quantity, which
    /// is what lets the diff pair `$1,204` with `$1,318` in preference to
    /// anything they happen to share characters with.
    ///
    /// Over scalars rather than characters, which is what upstream's code-unit
    /// filter comes to: every digit and every separator here is a single BMP
    /// unit, so a surrogate pair is always kept whole or dropped whole and the
    /// two walks cannot produce different strings.
    static func numericSkeleton(_ word: String) -> String {
        String(String.UnicodeScalarView(word.unicodeScalars.filter { scalar in
            !(scalar.value >= 0x30 && scalar.value <= 0x39)
                && !coreSeparatorScalars.contains(scalar)
        }))
    }

    /// Whether a token is a quantity.
    ///
    /// Strict on purpose, and on by default: merely holding a digit is not
    /// enough, or `COVID-19` and `2024-01-01` would morph by place value.
    /// Affixes are trimmed from both ends, and what is left must start and end
    /// with a digit and hold nothing but digits and core separators.
    /// Walked in UTF-16 code units, which is upstream's unit and the Kotlin
    /// twin's. It matters: an astral currency symbol is one `Character` and two
    /// code units, so a character walk would trim it as an affix where
    /// upstream does not, and `\u{1ECB0}5` would be a quantity on one platform
    /// and not on the other. Every member of every set here is a single BMP
    /// unit, so nothing else changes.
    ///
    /// It also means no value holding an astral character or a combining mark
    /// can reach `segmentNumber`, which is why that can go on splitting into
    /// characters.
    static func isNumericWord(_ word: String) -> Bool {
        let units = Array(word.utf16)
        var start = 0
        var end = units.count

        while start < end, isAffix(units[start], prefixUnits) {
            start += 1
        }
        while end > start, isAffix(units[end - 1], suffixUnits) {
            end -= 1
        }

        if start >= end { return false }
        if !isDigit(unit: units[start]) || !isDigit(unit: units[end - 1]) { return false }

        for index in start ..< end {
            let unit = units[index]
            if !isDigit(unit: unit), !coreSeparatorUnits.contains(unit) { return false }
        }

        return true
    }

    /// Whether a character of a numeric word is a digit or one of the symbols
    /// that travel with the places they belong to.
    static func classifyKind(_ character: Character) -> SegmentKind {
        isDigit(character) ? .digit : .symbol
    }

    /// The same classification for a segment whose text may be more than one
    /// character, which is what an older non-numeric segmentation of the same
    /// word can hand over.
    ///
    /// Upstream calls the single-character test on that string, and JavaScript
    /// compares strings lexicographically rather than rejecting the call: `"12"`
    /// reads as a digit because `"1"` sorts between `"0"` and `"9"`, while
    /// `"km"` does not because `"k"` sorts after `"9"`. Reproduced rather than
    /// corrected, because it decides which segments slide.
    static func classifyKind(text: String) -> SegmentKind {
        isDigitLexicographically(text) ? .digit : .symbol
    }

    /// JavaScript's `text >= "0" && text <= "9"`, on UTF-16 code units.
    ///
    /// A code-unit-wise comparison where, if one value is a prefix of the
    /// other, the shorter sorts first. Both bounds are a single unit, so:
    ///
    /// - `text >= "0"` holds when `text` is not empty and its first unit is not
    ///   below `"0"`, since a longer value beginning with `"0"` sorts after it.
    /// - `text <= "9"` holds when `text` is empty, or its first unit is below
    ///   `"9"`, or it is exactly `"9"`. `"9x"` sorts *after* `"9"` and so fails,
    ///   while `"12"` and even `"0x1f"` pass.
    private static func isDigitLexicographically(_ text: String) -> Bool {
        var units = text.utf16.makeIterator()
        guard let first = units.next() else { return false }
        guard first >= 0x30 else { return false }
        if first < 0x39 { return true }
        return first == 0x39 && units.next() == nil
    }

    private static func isAffix(_ unit: UInt16, _ set: Set<UInt16>) -> Bool {
        set.contains(unit) || isCurrency(unit: unit)
    }

    /// The three sets again, as code units and as scalars.
    ///
    /// Derived from the character sets rather than written out twice, so there
    /// is still one place to change what counts as a separator. Every member is
    /// a single BMP unit, which `coreSeparatorUnits` would silently break if one
    /// ever were not, so it is worth knowing that the sets are the same size.
    static let coreSeparatorUnits: Set<UInt16> = Set(coreSeparators.flatMap(\.utf16))
    static let coreSeparatorScalars: Set<Unicode.Scalar> =
        Set(coreSeparators.flatMap(\.unicodeScalars))
    private static let prefixUnits: Set<UInt16> = Set(prefixCharacters.flatMap(\.utf16))
    private static let suffixUnits: Set<UInt16> = Set(suffixCharacters.flatMap(\.utf16))
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
