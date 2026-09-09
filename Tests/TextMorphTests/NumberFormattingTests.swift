import Foundation
import Testing
@testable import TextMorph

/// Formatting a numeric value, against the JavaScript original.
///
/// Two ICU implementations reading the same CLDR data should agree, and mostly
/// do, but "should" is not a test. This is 4650 cases: 25 values, six fraction
/// lengths and 31 locales.
@Suite("Number formatting, against upstream")
struct NumberFormattingTests {
    let goldens: Goldens

    init() throws {
        goldens = try Fixtures.load(Goldens.self, from: "goldens")
    }

    @Test("Every value, fraction length and locale in the matrix")
    func agreesWithUpstream() {
        var failures: [String] = []
        for testCase in goldens.numberFormatting {
            let actual = NumberFormatting.format(
                testCase.value,
                decimals: testCase.decimals,
                locale: Locale(identifier: testCase.locale)
            )
            if actual != testCase.formatted {
                let decimals = testCase.decimals.map(String.init) ?? "default"
                failures.append(
                    "  \(testCase.value) decimals=\(decimals) \(testCase.locale):"
                        + " expected \(escaped(testCase.formatted)), got \(escaped(actual))"
                )
            }
        }
        #expect(
            failures.isEmpty,
            Comment(rawValue: "\(failures.count) of \(goldens.numberFormatting.count) disagree:\n"
                + failures.prefix(20).joined(separator: "\n"))
        )
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
