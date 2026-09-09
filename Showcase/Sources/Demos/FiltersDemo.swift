import SwiftUI
import TextMorph

private let filters = ["All Markets", "Markets (1)", "Markets (2)", "Markets (3)"]

/// A filter pill that gains a count.
struct FiltersDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: filters.count, interval: 1.5) { index in
            Stage {
                Chip {
                    TextMorph(filters[index], options: settings.options)
                        .textMorphFont(stageFont(size: 20))
                }
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "filters",
            name: "Filters",
            summary: "All Markets becoming Markets (1). The word Markets survives and slides "
                + "left as All leaves, and the digit inside the brackets rolls on its own "
                + "because a bracketed number is still a quantity.",
            capability: "a word leaving beside a quantity that rolls",
            code: """
            Chip { TextMorph("Markets (\\(count))") }
            """
        ) { FiltersDemo() }
    }
}
