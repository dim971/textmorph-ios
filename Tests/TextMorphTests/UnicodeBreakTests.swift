import Testing
@testable import TextMorph

/// The ported UAX #29 rules, replayed against Unicode's own conformance files.
///
/// These are not fixtures of upstream behaviour; they are the standard's own
/// test suite. If one of these fails, the rules are wrong, independently of
/// anything torph does.
@Suite("UAX #29 conformance")
struct UAX29ConformanceTests {
    @Test("The tables were generated from the version the rules were written for")
    func versionMatches() throws {
        let cases = try Fixtures.load(UnicodeConformanceFixture.self, from: "unicode-break-tests")
        #expect(cases.unicodeVersion == UnicodeBreakTables.unicodeVersion)
    }

    @Test("Every grapheme cluster break case")
    func graphemeConformance() throws {
        let cases = try Fixtures.load(UnicodeConformanceFixture.self, from: "unicode-break-tests")
        #expect(cases.grapheme.count > 700, "the conformance file looks truncated")

        var failures: [String] = []
        for testCase in cases.grapheme {
            let actual = UnicodeBreaks.graphemeBoundaries(of: testCase.value).map(\.value)
            if actual != testCase.expectedOffsets {
                failures.append(describe(testCase, actual: actual))
            }
        }
        #expect(
            failures.isEmpty,
            "\(failures.count) cases failed:\n\(failures.prefix(8).joined(separator: "\n"))"
        )
    }

    @Test("Every word break case")
    func wordConformance() throws {
        let cases = try Fixtures.load(UnicodeConformanceFixture.self, from: "unicode-break-tests")
        #expect(cases.word.count > 1800, "the conformance file looks truncated")

        var failures: [String] = []
        for testCase in cases.word {
            let actual = UnicodeBreaks.wordBoundaries(of: testCase.value).map(\.value)
            if actual != testCase.expectedOffsets {
                failures.append(describe(testCase, actual: actual))
            }
        }
        #expect(
            failures.isEmpty,
            "\(failures.count) cases failed:\n\(failures.prefix(8).joined(separator: "\n"))"
        )
    }

    private func report(_ failures: [String]) -> String {
        "\(failures.count) cases failed:\n" + failures.prefix(8).joined(separator: "\n")
    }

    private func describe(_ testCase: UnicodeConformanceFixture.Case, actual: [Int]) -> String {
        let codePoints = testCase.clusters
            .map { $0.map { String(format: "%04X", $0) }.joined(separator: " ") }
            .joined(separator: " | ")
        return "  \(codePoints)\n    expected \(testCase.expectedOffsets), got \(actual)"
            + "\n    \(testCase.note)"
    }
}
