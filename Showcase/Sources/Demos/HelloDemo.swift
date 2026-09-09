import SwiftUI
import TextMorph

/// The plainest thing the library does.
struct HelloDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle(["Hello world", "Hello there", "Goodbye world"])

    var body: some View {
        Tappable(hint: "Tap to change the value") {
            TextMorph(cycle.current, options: settings.options)
                .textMorphFont(.textStyle(.title))
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "hello",
            name: "Hello",
            summary: "A value changing, and nothing else. The words that survive the change move; "
                + "the ones that do not arrive and leave.",
            capability: "the word path of the segmenter",
            code: """
            TextMorph(greeting)
                .textMorphFont(.textStyle(.title))
            """
        ) { HelloDemo() }
    }
}
