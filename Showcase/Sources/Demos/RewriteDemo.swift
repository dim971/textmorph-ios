import SwiftUI
import TextMorph

/// A sentence replaced outright.
struct RewriteDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle([
        "the quick brown fox",
        "a slow green turtle",
        "one lazy grey cat"
    ])

    var body: some View {
        Tappable(hint: "Tap to rewrite") {
            TextMorph(cycle.current, options: settings.options)
                .textMorphFont(.textStyle(.title2))
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "rewrite",
            name: "Rewrite",
            summary: "Nothing survives, so the old sentence recedes as one shape rather than as "
                + "twenty characters each going its own way. Six adjacent characters all leaving "
                + "is where that switch happens.",
            capability: "the group replacement path",
            code: """
            TextMorph(sentence)
                .textMorphFont(.textStyle(.title2))
            """
        ) { RewriteDemo() }
    }
}
