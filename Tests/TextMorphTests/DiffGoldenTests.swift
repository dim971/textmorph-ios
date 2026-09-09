import Foundation
import Testing
@testable import TextMorph

/// The segment diff, against the JavaScript original.
///
/// The corpus is every ordered pair of a 22-value corpus, with numbers on and
/// off, plus the caret cases: 976 diffs in all. A branch of the diff that this
/// port got wrong shows up here as a list of the pairs that reach it, which is
/// far more useful than a single failing assertion.
@Suite("The diff, against upstream")
struct DiffGoldenTests {
    let goldens: Goldens

    init() throws {
        goldens = try Fixtures.load(Goldens.self, from: "goldens")
    }

    @Test("The corpus is the sweep it claims to be")
    func corpusIsWhatItClaims() {
        #expect(goldens.diffSegments.count > 900, "the corpus looks truncated")
        #expect(goldens.diffSegments.contains { $0.cursor != nil })
        #expect(goldens.diffSegments.contains { !$0.numbers })
        #expect(goldens.diffSegments.contains { !$0.splits.isEmpty })
        #expect(goldens.diffSegments.contains { $0.after.contains("\n") })
    }

    @Test("Every diff in the sweep")
    func agreesWithUpstream() {
        var failures: [String] = []
        for testCase in goldens.diffSegments {
            let problems = problems(in: testCase)
            if !problems.isEmpty {
                let caret = testCase.cursor.map { " caret \($0)" } ?? ""
                failures.append(
                    "  \(escaped(testCase.before)) to \(escaped(testCase.after))"
                        + " numbers=\(testCase.numbers)\(caret)\n"
                        + problems.joined(separator: "\n")
                )
            }
        }

        let checked = goldens.diffSegments.count
        #expect(
            failures.isEmpty,
            Comment(rawValue: "\(failures.count) of \(checked) diffs disagree:\n"
                + failures.prefix(6).joined(separator: "\n"))
        )
    }

    /// Replays one recorded diff, and says what disagrees.
    private func problems(in testCase: GoldenDiffCase) -> [String] {
        let minter = MintedIds()
        let previous = TextSegmenter.segmentText(
            testCase.before,
            locale: defaultMorphLocale,
            numbers: testCase.numbers,
            minter: minter
        )

        // Canonicalise across both sides at once, so an identity inherited from
        // the old segmentation gets the same name in both.
        var renamer = Renamer()
        for segment in previous {
            _ = renamer.name(segment.id)
        }

        guard previous.map({ renamer.name($0.id) }) == testCase.previous else {
            return [
                "    the starting segmentation already differs",
                "    expected \(testCase.previous)",
                "    got      \(previous.map { renamer.name($0.id) })"
            ]
        }

        let result = SegmentDiff.diffSegments(
            previous,
            testCase.after,
            locale: defaultMorphLocale,
            options: DiffOptions(
                numbers: testCase.numbers,
                cursorIndex: testCase.cursor.map { UTF16Offset($0) }
            ),
            minter: minter
        )

        let recorded = record(result, against: previous, renamer: &renamer)

        var problems: [String] = []
        if recorded.segments != testCase.segments {
            problems.append("    segments expected \(describe(testCase.segments))")
            problems.append("             got      \(describe(recorded.segments))")
        }
        if recorded.alignment != testCase.alignment {
            problems.append("    alignment expected \(describe(testCase.alignment))")
            problems.append("              got      \(describe(recorded.alignment))")
        }
        if recorded.splits != testCase.splits {
            problems.append("    splits expected \(testCase.splits)")
            problems.append("           got      \(recorded.splits)")
        }
        return problems
    }

    /// A diff in the shape the fixture records it in.
    private struct Recorded {
        let segments: [GoldenSegment]
        let alignment: [Int?]
        let splits: [String: [GoldenSplitSegment]]
    }

    private func record(
        _ result: DiffResult, against previous: [Segment], renamer: inout Renamer
    ) -> Recorded {
        var positions: [String: Int] = [:]
        for (index, segment) in previous.enumerated() {
            positions[segment.id] = index
        }

        var segments: [GoldenSegment] = []
        var alignment: [Int?] = []
        for segment in result.segments {
            segments.append(GoldenSegment(
                id: renamer.name(segment.id),
                string: segment.string,
                kind: segment.kind?.rawValue
            ))
            alignment.append(positions[segment.id])
        }

        var splits: [String: [GoldenSplitSegment]] = [:]
        for (key, value) in result.splits {
            var split: [GoldenSplitSegment] = []
            for segment in value {
                split.append(GoldenSplitSegment(
                    id: renamer.name(segment.id), string: segment.string
                ))
            }
            splits[renamer.name(key)] = split
        }

        return Recorded(segments: segments, alignment: alignment, splits: splits)
    }

    // MARK: - helpers

    /// Renames minted identities the way the fixture renames them, keeping one
    /// numbering across the old and the new segmentation.
    private struct Renamer {
        private var seen: [String: String] = [:]

        mutating func name(_ id: String) -> String {
            guard id.hasPrefix("\u{0000}n") else { return id }
            if let existing = seen[id] { return existing }
            let renamed = "#\(seen.count)"
            seen[id] = renamed
            return renamed
        }
    }

    private func describe(_ segments: [GoldenSegment]) -> String {
        segments.map { segment in
            let kind = segment.kind.map { ":\($0)" } ?? ""
            return "\(escaped(segment.id))=\(escaped(segment.string))\(kind)"
        }.joined(separator: " | ")
    }

    private func describe(_ alignment: [Int?]) -> String {
        "[" + alignment.map { $0.map(String.init) ?? "-" }.joined(separator: ", ") + "]"
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
