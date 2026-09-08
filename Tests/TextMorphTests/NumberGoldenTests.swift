import Foundation
import Testing
@testable import TextMorph

/// The number rules and the place alignment, against the JavaScript original.
@Suite("Numbers, against upstream")
struct NumberGoldenTests {
    let goldens: Goldens

    init() throws {
        goldens = try Fixtures.load(Goldens.self, from: "goldens")
    }

    @Test("Whether a token is a quantity")
    func numericWordRecognition() {
        var failures: [String] = []
        for testCase in goldens.numberRules.isNumericWord {
            let actual = NumberRules.isNumericWord(testCase.token)
            if actual != testCase.result {
                failures.append("  \(escaped(testCase.token)): expected \(testCase.result), got \(actual)")
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("The locale's decimal separator")
    func decimalSeparators() {
        var failures: [String] = []
        for testCase in goldens.numberRules.decimalSeparator {
            let locale = Locale(identifier: testCase.locale)
            let actual = String(NumberRules.decimalSeparator(for: locale))
            if actual != testCase.separator {
                failures.append(
                    "  \(testCase.locale): expected \(escaped(testCase.separator)), got \(escaped(actual))"
                )
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("A number with nothing to carry from")
    func freshSegmentation() {
        var failures: [String] = []
        for testCase in goldens.segmentNumber.fresh {
            let minter = MintedIds()
            let actual = NumberSegmenter.segmentNumber(testCase.value, minter: minter)
            let canonical = canonicalise(actual)
            if canonical != testCase.segments {
                failures.append("""
                  \(escaped(testCase.value))
                    expected \(testCase.segments)
                    got      \(canonical)
                """)
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("Matching by place value, with a full stop for a decimal separator")
    func placeMatching() {
        check(goldens.segmentNumber.place, decimalCharacter: ".")
    }

    @Test("Matching by place value, with a comma for a decimal separator")
    func placeMatchingWithComma() {
        check(goldens.segmentNumber.placeComma, decimalCharacter: ",")
    }

    @Test("Matching by caret, for a field being typed into")
    func cursorMatching() {
        var failures: [String] = []
        for testCase in goldens.segmentNumber.cursor {
            let minter = MintedIds()
            let previous = NumberSegmenter.segmentNumber(testCase.before, minter: minter)
            let actual = NumberSegmenter.segmentNumber(
                testCase.after,
                previous: previous,
                cursor: UTF16Offset(testCase.cursor),
                decimalCharacter: ".",
                minter: minter
            )
            let strings = actual.map(\.string)
            let alignment = alignment(of: actual, against: previous)
            if strings != testCase.strings || alignment != testCase.alignment {
                failures.append("""
                  \(escaped(testCase.before)) to \(escaped(testCase.after)), caret \(testCase.cursor)
                    expected strings \(testCase.strings) alignment \(describe(testCase.alignment))
                    got      strings \(strings) alignment \(describe(alignment))
                """)
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    // MARK: - helpers

    /// A failure list as a comment the testing library will print.
    private func report(_ failures: [String]) -> Comment {
        Comment(rawValue: "\n" + failures.joined(separator: "\n"))
    }

    private func check(
        _ cases: [GoldenSegmentNumber.PlaceCase],
        decimalCharacter: Character
    ) {
        var failures: [String] = []
        for testCase in cases {
            let minter = MintedIds()
            let previous = NumberSegmenter.segmentNumber(testCase.before, minter: minter)
            let actual = NumberSegmenter.segmentNumber(
                testCase.after,
                previous: previous,
                decimalCharacter: decimalCharacter,
                minter: minter
            )
            let alignment = alignment(of: actual, against: previous)
            var problems: [String] = []
            if alignment != testCase.alignment {
                problems.append(
                    "    alignment expected \(describe(testCase.alignment)) got \(describe(alignment))"
                )
            }
            if let expected = testCase.strings, actual.map(\.string) != expected {
                problems.append("    strings expected \(expected) got \(actual.map(\.string))")
            }
            if let expected = testCase.kinds, actual.map(\.kind.rawValue) != expected {
                problems.append("    kinds expected \(expected) got \(actual.map(\.kind.rawValue))")
            }
            if !problems.isEmpty {
                failures.append(
                    "  \(escaped(testCase.before)) to \(escaped(testCase.after))\n"
                        + problems.joined(separator: "\n")
                )
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    /// Which old segment each new one carries on from, by index.
    private func alignment(of next: [NumberSegment], against previous: [NumberSegment]) -> [Int?] {
        var positions: [String: Int] = [:]
        for (index, segment) in previous.enumerated() {
            positions[segment.id] = index
        }
        return next.map { positions[$0.id] }
    }

    /// Minted identities renamed the way the fixture renames them.
    private func canonicalise(_ segments: [NumberSegment]) -> [GoldenSegment] {
        var seen: [String: String] = [:]
        return segments.map { segment in
            var id = segment.id
            if id.hasPrefix("\u{0000}n") {
                if seen[id] == nil { seen[id] = "#\(seen.count)" }
                id = seen[id] ?? id
            }
            return GoldenSegment(id: id, string: segment.string, kind: segment.kind.rawValue)
        }
    }

    private func describe(_ alignment: [Int?]) -> String {
        "[" + alignment.map { $0.map(String.init) ?? "-" }.joined(separator: ", ") + "]"
    }

    /// Escapes the characters that make a failure message unreadable in a
    /// terminal, which in this corpus is most of the interesting ones.
    private func escaped(_ value: String) -> String {
        let body = value.unicodeScalars.map { scalar -> String in
            switch scalar.value {
            case 0x20 ... 0x7E: String(Character(scalar))
            default: String(format: "\\u{%04X}", scalar.value)
            }
        }.joined()
        return "\"\(body)\""
    }
}
