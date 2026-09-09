import SwiftUI
import TextMorph

/// Upstream's script, step for step, including the delays.
///
/// It is worth reading as a story: type twenty dollars, put the caret back and
/// insert a four, watch it become four thousand and twenty, then put a point in
/// and watch the same digits become four dollars twenty. The same five
/// characters mean three different amounts, and the caret is the only thing
/// telling the morph which reading is happening.
private struct Keystroke {
    let value: String
    let caret: Int
    /// How long to hold this step before the next, in seconds.
    let delay: Double
}

private let script: [Keystroke] = [
    Keystroke(value: "$", caret: 1, delay: 0),
    Keystroke(value: "$2", caret: 2, delay: 0.15),
    Keystroke(value: "$20", caret: 3, delay: 1.2),
    Keystroke(value: "$20", caret: 3, delay: 1.8),
    Keystroke(value: "$20", caret: 1, delay: 0.2),
    Keystroke(value: "$420", caret: 2, delay: 0.4),
    Keystroke(value: "$4,020", caret: 4, delay: 1.8),
    Keystroke(value: "$420", caret: 2, delay: 0.4),
    Keystroke(value: "$4.20", caret: 3, delay: 0.4),
    Keystroke(value: "$4.20", caret: 3, delay: 1.8),
    Keystroke(value: "$4.20", caret: 5, delay: 1.8),
    Keystroke(value: "$4.2", caret: 4, delay: 0.2),
    Keystroke(value: "$4", caret: 2, delay: 0.2),
    Keystroke(value: "$", caret: 1, delay: 0.2)
]

/// A scripted edit, so the caret can be watched doing its work.
struct AmountDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    var body: some View {
        let keystroke = script[step]

        return Stage(caption: "a scripted edit, caret and all") {
            HStack(spacing: 2) {
                TextMorph(keystroke.value, options: settings.options, cursorIndex: keystroke.caret)
                    .textMorphFont(stageFont(size: 34))
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 34)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 12))
        }
        .task(id: step) {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(max(0.001, keystroke.delay)))
            guard !Task.isCancelled else { return }
            step = (step + 1) % script.count
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "amount",
            name: "Amount",
            summary: "The same five characters read three ways. Twenty dollars becomes four "
                + "thousand and twenty because a digit went in front of the two, then four "
                + "dollars twenty because a point went between them. Nothing but the caret "
                + "tells the morph which of those happened, and the digits move completely "
                + "differently in each case.",
            capability: "the caret deciding what a change means",
            code: """
            TextMorph("$4,020", cursorIndex: 4)   // a digit was inserted
            TextMorph("$4.20", cursorIndex: 3)    // a point was
            """
        ) { AmountDemo() }
    }
}
