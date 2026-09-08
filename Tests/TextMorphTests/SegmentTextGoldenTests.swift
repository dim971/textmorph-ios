import Foundation
import Testing
@testable import TextMorph

/// The segmenter, against the JavaScript original.
@Suite("Segmentation, against upstream")
struct SegmentTextGoldenTests {
    let goldens: Goldens

    init() throws {
        goldens = try Fixtures.load(Goldens.self, from: "goldens")
    }

    @Test("Every value the corpus segments the same way")
    func agreesWithUpstream() {
        var failures: [String] = []
        for testCase in goldens.segmentText where testCase.diverges == nil {
            let actual = canonicalise(TextSegmenter.segmentText(
                testCase.value, locale: defaultMorphLocale, numbers: testCase.numbers
            ))
            if actual != testCase.segments {
                failures.append("""
                  \(escaped(testCase.value)) numbers=\(testCase.numbers)
                    expected \(describe(testCase.segments))
                    got      \(describe(actual))
                """)
            }
        }
        #expect(failures.isEmpty, Comment(rawValue: "\n" + failures.joined(separator: "\n")))
    }

    @Test("The corpus reaches both segmentation paths and every cluster shape")
    func corpusIsWhatItClaims() {
        let values = Set(goldens.segmentText.map(\.value))
        #expect(values.count >= 50, "the corpus looks truncated")
        // A value with a space takes the word path, one without takes the
        // grapheme path, and a value with a line break takes the word path on
        // every line. All three have to be exercised or the fixture proves
        // little.
        #expect(values.contains { $0.contains(" ") && !$0.contains("\n") })
        #expect(values.contains { !$0.contains(" ") && !$0.contains("\n") && !$0.isEmpty })
        #expect(values.contains { $0.contains("\n") })
        #expect(values.contains { $0.unicodeScalars.contains { $0.value > 0xFFFF } })
    }

    @Test("The cases marked as diverging are the only ones that do")
    func divergenceIsConfinedToCJK() {
        // Recorded rather than skipped: if one of these ever starts agreeing,
        // or a new one appears, that is worth knowing rather than passing
        // silently.
        var unexpected: [String] = []
        for testCase in goldens.segmentText where testCase.diverges != nil {
            let actual = canonicalise(TextSegmenter.segmentText(
                testCase.value, locale: defaultMorphLocale, numbers: testCase.numbers
            ))
            if actual == testCase.segments {
                unexpected.append("  \(escaped(testCase.value)) now agrees: \(testCase.diverges ?? "")")
            }
        }
        #expect(
            unexpected.isEmpty,
            Comment(rawValue: "\n" + unexpected.joined(separator: "\n"))
        )
    }

    // MARK: - helpers

    private func canonicalise(_ segments: [Segment]) -> [GoldenSegment] {
        var seen: [String: String] = [:]
        return segments.map { segment in
            var id = segment.id
            if id.hasPrefix("\u{0000}n") {
                if seen[id] == nil { seen[id] = "#\(seen.count)" }
                id = seen[id] ?? id
            }
            return GoldenSegment(id: id, string: segment.string, kind: segment.kind?.rawValue)
        }
    }

    private func describe(_ segments: [GoldenSegment]) -> String {
        segments.map { segment in
            let kind = segment.kind.map { ":\($0)" } ?? ""
            return "\(escaped(segment.id))=\(escaped(segment.string))\(kind)"
        }.joined(separator: " | ")
    }

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
