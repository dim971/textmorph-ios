import SwiftUI
import TextMorph

private let walletStates = [
    "Connect wallet",
    "Connecting\u{2026}",
    "0xd55a\u{2026}d2685",
    "lochie.eth"
]

/// A connect button that becomes an address and then a name.
struct WalletDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: walletStates.count, interval: 1.8) { index in
            Stage {
                Chip {
                    HStack(spacing: index >= 2 ? 8 : 0) {
                        // An avatar appears once there is an account to put one
                        // on, which is what makes the pill grow from the left as
                        // well as the right. Upstream loads a photograph; a disc
                        // is enough to show the pill absorbing it.
                        if index >= 2 {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 20, height: 20)
                                .transition(.scale.combined(with: .opacity))
                        }
                        TextMorph(walletStates[index], options: settings.options)
                            .textMorphFont(stageFont(size: 18))
                    }
                    .animation(.easeOut(duration: 0.2), value: index >= 2)
                }
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "wallet",
            name: "Wallet",
            summary: "Connect wallet, then an ellipsis while it connects, then a truncated "
                + "address, then a name. Four states with almost nothing in common, so most "
                + "of it is a group replacement, and the pill's width carries the whole way.",
            capability: "a chain of unrelated values, and the pill that holds them",
            code: """
            Chip { TextMorph(state) }
            """
        ) { WalletDemo() }
    }
}
