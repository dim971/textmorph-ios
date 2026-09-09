import SwiftUI
import TextMorph

/// A value with line breaks in it.
struct ReflowDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle([
        "Two lines\nof text",
        "Three lines\nof text\nthis time",
        "One line",
        ""
    ])

    var body: some View {
        Tappable(hint: "Tap to gain or lose a line") {
            TextMorph(cycle.current, options: settings.options)
                .textMorphFont(.textStyle(.title2))
                .multilineTextAlignment(.center)
                .frame(height: 130, alignment: .center)
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "reflow",
            name: "Reflow",
            summary: "Line breaks are the only thing that makes a line here: there is no "
                + "automatic wrapping, deliberately, because wrapping would change which "
                + "segments are adjacent and so change the whole morph. The last step empties "
                + "the value, which holds the old box rather than collapsing it.",
            capability: "multi-line values, and the empty transition",
            code: """
            TextMorph("Two lines\\nof text")
                .multilineTextAlignment(.center)
            """
        ) { ReflowDemo() }
    }
}
