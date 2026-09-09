import SwiftUI
import TextMorph

/// A row of labels that reorders.
struct FiltersDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle([
        "Unread  Flagged  Recent",
        "Recent  Unread  Flagged",
        "Flagged  Recent  Unread"
    ])

    var body: some View {
        Tappable(hint: "Tap to reorder") {
            TextMorph(cycle.current, options: settings.options)
                .textMorphFont(.textStyle(.headline))
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "filters",
            name: "Filters",
            summary: "The same words in a different order. A word that moved keeps its identity "
                + "and travels whole, rather than being cut into characters that fly separately. "
                + "A subsequence cannot see a reordering, so a second pass looks for it.",
            capability: "the exact-match reordering pass of the diff",
            code: """
            TextMorph(filters.joined(separator: "  "))
                .textMorphFont(.textStyle(.headline))
            """
        ) { FiltersDemo() }
    }
}
