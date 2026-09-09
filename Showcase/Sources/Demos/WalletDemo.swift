import SwiftUI
import TextMorph

/// A balance, which is what place-value morphing is for.
struct WalletDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var balance = 1204.0

    var body: some View {
        Tappable(hint: "Tap to spend a little") {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                TextMorph(balance, options: settings.options(decimals: 2))
                    .textMorphFont(.system(size: 40, weight: .semibold, design: .rounded))
            }
        } advance: {
            balance = (balance - Double(Int.random(in: 80 ... 400))).rounded()
            if balance < 100 { balance = 1204 }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "wallet",
            name: "Wallet",
            summary: "The one that makes the case for the whole library. 1,204 becoming 1,318 "
                + "rolls the hundreds and the tens and leaves the thousands alone, because a "
                + "digit's identity is its column rather than its position in the string.",
            capability: "place-value alignment",
            code: """
            TextMorph(balance, options: TextMorphOptions(decimals: 2))
                .textMorphFont(.system(size: 40, weight: .semibold, design: .rounded))
            """
        ) { WalletDemo() }
    }
}
