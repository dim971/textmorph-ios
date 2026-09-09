import SwiftUI
import TextMorph

private let figures = ["1,248,392", "1,248K", "1.2M", "1M"]

/// One count, written four ways.
struct SquishyNumberDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: figures.count, interval: 3.4) { index in
            Stage {
                TextMorph(figures[index], options: settings.options)
                    .textMorphFont(stageFont(size: 34))
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "squishy",
            name: "Squishy number",
            summary: "1,248,392 shortening to 1,248K to 1.2M to 1M. Each step drops most of "
                + "the number, and the digits that survive are the leading ones, so the value "
                + "collapses from the right rather than being replaced. The step from 1,248K "
                + "to 1.2M is the interesting one: the 1 and the 2 hold while everything "
                + "between them leaves.",
            capability: "a quantity losing columns from the right",
            code: """
            TextMorph(abbreviated(count))
            """
        ) { SquishyNumberDemo() }
    }
}
