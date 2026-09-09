import SwiftUI
import TextMorph

/// The same amount in another locale.
struct CurrencySwapDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle([
        ("en-US", "$"), ("de-DE", "\u{20AC}"), ("fr-FR", "\u{20AC}"), ("en-GB", "\u{00A3}")
    ])

    private let amount = 1234.5

    var body: some View {
        Tappable(hint: "Tap to change the locale") {
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(cycle.current.1)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextMorph(
                        amount,
                        options: settings.options(
                            decimals: 2, locale: Locale(identifier: cycle.current.0)
                        )
                    )
                    .textMorphFont(.system(size: 36, weight: .semibold))
                }
                Text(cycle.current.0)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "currency",
            name: "Currency swap",
            summary: "One number, four locales. The decimal separator is the pivot every column "
                + "is measured from, so changing it moves every digit; the grouping separator "
                + "changes shape with it, and some locales group with a space rather than a "
                + "comma.",
            capability: "the locale's decimal separator as the pivot",
            code: """
            TextMorph(amount, options: TextMorphOptions(
                decimals: 2, locale: Locale(identifier: "de-DE")
            ))
            """
        ) { CurrencySwapDemo() }
    }
}
