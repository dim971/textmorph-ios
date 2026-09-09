import SwiftUI
import TextMorph

/// Text arriving a word at a time, the way a model writes it.
struct StreamingDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var wordCount = 1

    /// Short enough to fit a catalogue row, since a morph overflows rather than
    /// wrapping.
    private static let words = ["Text", "arrives", "one", "word", "at", "a", "time."]

    private var text: String {
        Self.words.prefix(wordCount).joined(separator: " ")
    }

    var body: some View {
        Ticking(interval: 0.45) {
            TextMorph(text, options: settings.options)
                .textMorphFont(.textStyle(.title3))
        } advance: {
            // Back to one word rather than none: an empty value is a state
            // the library handles, but it reads as a broken row in a list.
            wordCount = wordCount >= Self.words.count ? 1 : wordCount + 1
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "streaming",
            name: "Streaming",
            summary: "A value appended to, over and over. Each word arrives while the ones before "
                + "it hold still, which is the case a cross-fade cannot do at all.",
            capability: "morphs arriving faster than they settle",
            code: """
            // words arriving one at a time
            TextMorph(words.prefix(count).joined(separator: " "))
            """
        ) { StreamingDemo() }
    }
}
