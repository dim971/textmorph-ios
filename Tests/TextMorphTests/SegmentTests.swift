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
