import Foundation
import Testing
@testable import TextMorph

/// Formatting a numeric value, against the JavaScript original.
///
/// Two ICU implementations reading the same CLDR data should agree, and mostly
/// do, but "should" is not a test. This is 4650 cases: 25 values, six fraction
/// lengths and 31 locales.
///
/// They do not read the *same* CLDR data, and this suite is how that was found
/// out. CLDR groups Swiss German with U+0027 in one version and U+2019 in
/// another, so Node's ICU and a device's ICU disagree about de-CH depending on
/// the OS: 36 of these cases pass on macOS 26 and fail on macOS 15, for that
/// one character. The comparison therefore treats those two apostrophes as the
/// same separator and asserts that nothing else differs, rather than pretending
/// the corpus agrees or dropping the locale that exposed it.
///
/// The consequence for the engine mattered more than the test did. U+2019 was
/// not in upstream's set of separators allowed between digits, so a de-CH
/// number would have rolled by place value on one OS version and morphed
/// character by character on the next. It is in the set now; see
/// `NumberRules.coreSeparators`.
@Suite("Number formatting, against upstream")
struct NumberFormattingTests {
    let goldens: Goldens

    init() throws {
        goldens = try Fixtures.load(Goldens.self, from: "goldens")
    }

    @Test("Every value, fraction length and locale in the matrix")
    func agreesWithUpstream() {
        var failures: [String] = []
        var apostrophes: Set<String> = []

        for testCase in goldens.numberFormatting {
            let actual = NumberFormatting.format(
                testCase.value,
                decimals: testCase.decimals,
                locale: Locale(identifier: testCase.locale)
            )
            guard actual != testCase.formatted else { continue }

            // The one difference between two CLDR versions: which apostrophe
            // Swiss German groups with. Treated as the same separator, and
            // recorded, so anything else still fails.
            if normalisingApostrophes(actual) == normalisingApostrophes(testCase.formatted) {
                apostrophes.insert(testCase.locale)
                continue
            }

            let decimals = testCase.decimals.map(String.init) ?? "default"
            failures.append(
                "  \(testCase.value) decimals=\(decimals) \(testCase.locale):"
                    + " expected \(escaped(testCase.formatted)), got \(escaped(actual))"
            )
        }

        #expect(
            failures.isEmpty,
            Comment(rawValue: "\(failures.count) of \(goldens.numberFormatting.count) disagree:\n"
                + failures.prefix(20).joined(separator: "\n"))
        )
        // Confined to the locale that is known to group with an apostrophe. A
        // second locale appearing here means CLDR moved something else.
        #expect(
            apostrophes.isSubset(of: ["de-CH"]),
            Comment(rawValue: "apostrophe differences in \(apostrophes.sorted())")
        )
    }

    /// The two apostrophes CLDR has used to group Swiss German, as one.
    private func normalisingApostrophes(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{2019}", with: "'")
    }

    @Test("A half rounds away from zero, not towards positive infinity")
    func halvesRoundAwayFromZero() {
        // The distinction only shows on a negative value, and it is the one
        // place a rounding mode's name is easy to trust and be wrong about.
        #expect(NumberFormatting.format(1.5, decimals: 0) == "2")
        #expect(NumberFormatting.format(-1.5, decimals: 0) == "-2")
        #expect(NumberFormatting.format(2.5, decimals: 0) == "3")
        #expect(NumberFormatting.format(-2.5, decimals: 0) == "-3")
    }

    @Test("Asking for no fraction length gives Intl's default of at most three")
    func defaultFractionLength() {
        #expect(NumberFormatting.format(1.5) == "1.5")
        #expect(NumberFormatting.format(1) == "1")
        #expect(NumberFormatting.format(1.23456) == "1.235")
        #expect(NumberFormatting.defaultFractionDigits == 0 ... 3)
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
