import SwiftUI
import TextMorph

private let currencies = ["$99.00", "\u{20AC}99.00", "\u{00A3}99.00", "\u{00A5}99.00"]

/// The same amount behind four different symbols.
struct CurrencySwapDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: currencies.count, interval: 1.4) { index in
            Stage {
                TextMorph(currencies[index], options: settings.options)
                    .textMorphFont(stageFont(size: 40))
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "currency",
            name: "Currency swap",
            summary: "Only the symbol changes, and the digits do not move at all. A currency "
                + "symbol is an affix: it is trimmed before the columns are aligned, so it is "
                + "free to be replaced without disturbing the number it sits in front of. The "
                + "four symbols are different widths, so the box breathes while the digits hold.",
            capability: "affix trimming, seen from the affix's side",
            code: """
            TextMorph("$99.00")
            TextMorph("\u{20AC}99.00")
            """
        ) { CurrencySwapDemo() }
    }
}
