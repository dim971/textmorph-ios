import SwiftUI
import TextMorph

private let actionStates = ["Processing Transaction", "Transaction Safe"]

/// A status that resolves, with the icon resolving beside it.
struct ActionDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: actionStates.count, interval: 2) { index in
            Stage {
                Chip {
                    HStack(spacing: 10) {
                        if index == 0 {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.accentColor)
                        }
                        TextMorph(
                            actionStates[index],
                            options: settings.options(
                                ease: ShowcaseSettings.actionCurve, duration: 600
                            )
                        )
                        .textMorphFont(stageFont(size: 18))
                    }
                }
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "action",
            name: "Action",
            summary: "Processing Transaction becoming Transaction Safe. The word Transaction "
                + "survives and travels the width of Processing, which is the longest journey "
                + "any segment makes in this catalogue. On a curve whose control points rise "
                + "past one, so it arrives, overshoots a little and settles.",
            capability: "a long word journey, and a curve that overshoots",
            code: """
            TextMorph(state, options: TextMorphOptions(
                duration: 600,
                ease: .bezier(CubicBezier(0.41, 1.03, 0.6, 1.03))
            ))
            """
        ) { ActionDemo() }
    }
}
