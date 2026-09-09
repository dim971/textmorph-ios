import SwiftUI
import TextMorph

/// A signed change, where the sign is part of the morph.
struct DeltaDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle([2.4, -1.8, 5.1, -0.3, 12.7])

    private var text: String {
        let sign = cycle.current < 0 ? "-" : "+"
        return "\(sign)\(abs(cycle.current))%"
    }

    var body: some View {
        Tappable(hint: "Tap for the next reading") {
            HStack(spacing: 8) {
                Image(systemName: cycle.current < 0 ? "arrow.down.right" : "arrow.up.right")
                    .foregroundStyle(cycle.current < 0 ? .red : .green)
                TextMorph(text, options: settings.options)
                    .textMorphFont(.system(size: 34, weight: .medium))
                    .textMorphColour(cycle.current < 0 ? .red : .green)
            }
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "delta",
            name: "Delta",
            summary: "A sign and a percent sign around the digits. Both are affixes: they pair "
                + "off before the columns are aligned, so the digits still roll by place while "
                + "the sign changes on its own.",
            capability: "affix trimming, and symbols sliding from below",
            code: """
            TextMorph("\\(sign)\\(abs(change))%")
                .textMorphColour(change < 0 ? .red : .green)
            """
        ) { DeltaDemo() }
    }
}
