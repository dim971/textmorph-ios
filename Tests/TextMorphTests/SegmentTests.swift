import Testing
@testable import TextMorph

@Suite("The segment model")
struct SegmentTests {
    @Test("A value's length is counted in UTF-16 code units, not in characters")
    func utf16LengthCountsCodeUnits() {
        // The distinction only bites above the basic plane, which is exactly
        // where upstream's ids come from a different number than Swift's.
        #expect("abc".utf16Length == UTF16Offset(3))
        #expect("abc".count == 3)

        // One grapheme cluster, one scalar, two code units.
        #expect("\u{1F600}".utf16Length == UTF16Offset(2))
        #expect("\u{1F600}".count == 1)

        // One grapheme cluster, five scalars, seven code units.
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
        #expect(family.utf16Length == UTF16Offset(8))
        #expect(family.count == 1)

        // A combining mark: one cluster, two code units.
        #expect("e\u{0301}".utf16Length == UTF16Offset(2))
        #expect("e\u{0301}".count == 1)
    }

    @Test("Offsets add, subtract and order as numbers")
    func offsetArithmetic() {
        var offset = UTF16Offset(4)
        offset += 3
        #expect(offset == UTF16Offset(7))
        #expect(offset - 2 == UTF16Offset(5))
        #expect(UTF16Offset(1) < UTF16Offset(2))
        #expect(offset.description == "7")

        let literal: UTF16Offset = 9
        #expect(literal.value == 9)
    }

    @Test("Only a normalised space separates words")
    func separatorRecognition() {
        #expect(Segment(id: "space-0", string: "\u{00A0}").isWordSeparator)
        // Upstream keeps a run of ordinary spaces as one non-separating segment.
        #expect(!Segment(id: "gap", string: "  ").isWordSeparator)
        #expect(!Segment(id: "gap", string: " ").isWordSeparator)
        #expect(Segment(id: "newline-3", string: "\n").isNewline)
    }
}

/// What a "character" is, and where the two candidate answers differ.
///
/// The unit a value is cut into decides identities and so decides what moves,
/// and there are three plausible units: a UTF-16 code unit, which is
/// upstream's; a `Character`, which is what the platform's ICU says today; and
/// an extended grapheme cluster by the rules in `Core`, which is what both
/// ports use. This suite is the Kotlin twin's, assertion for assertion, so a
/// port drifting onto a different unit fails here rather than in a golden with
/// no explanation.
@Suite("The unit a character is")
struct CharacterUnitTests {
    @Test("A word is cut by the ported rules, not by the platform's")
    func graphemesFollowTheRules() {
        // A family emoji is one cluster of five scalars and eight code units,
        // and a combining sequence is one cluster of two. Cutting on code
        // units would give eight pieces and one and a half emoji.
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
        #expect(family.graphemes == [family])
        #expect("e\u{0301}".graphemes == ["e\u{0301}"])
        #expect("caf\u{00E9}".graphemes == ["c", "a", "f", "\u{00E9}"])
        #expect("1,204".graphemes == ["1", ",", "2", "0", "4"])
        #expect("".graphemes.isEmpty)

        // A regional indicator pair is one flag, which is GB12 and GB13 and is
        // the case a naive scalar walk gets wrong.
        #expect("\u{1F1EB}\u{1F1F7}".graphemes.count == 1)
    }

    @Test("A quantity is decided in code units, which is upstream's unit")
    func numericWordsUseCodeUnits() {
        #expect(NumberRules.isNumericWord("$1,204"))
        #expect(NumberRules.isNumericWord("12%"))
        #expect(!NumberRules.isNumericWord("COVID-19"))

        // U+1ECB0 INDIC SIYAQ RUPEE MARK is a currency symbol in general
        // category Sc, and it is astral. As one character it would be trimmed
        // as an affix and this would be a quantity; as the two surrogates
        // upstream and the Kotlin twin see, neither is in Sc, so it is not.
        #expect(!NumberRules.isNumericWord("\u{1ECB0}5"))
        #expect(NumberRules.isCurrency("\u{1ECB0}"), "it is a currency symbol as a character")

        // A combining mark next to a digit, for the same reason in reverse: as
        // one character it is not a digit at all.
        #expect(!NumberRules.isNumericWord("1\u{0301}2"))
        #expect(NumberRules.hasDigit("1\u{0301}2"), "the code unit walk still sees the 1")
    }
}
