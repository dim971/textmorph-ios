import SwiftUI
import TextMorph

/// A quantity and its unit, which change together.
struct UnitsDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle(["1.2 GB", "980 MB", "412 MB", "8.4 GB", "64 KB"])

    var body: some View {
        Tappable(hint: "Tap for the next size") {
            TextMorph(cycle.current, options: settings.options)
                .textMorphFont(.system(size: 34, weight: .medium))
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "units",
            name: "Units",
            summary: "Two words, one of them a quantity and one of them not. The quantity morphs "
                + "by place value and the unit morphs by character, in the same value, because "
                + "the numeric pass runs over the finished segmentation rather than inside it.",
            capability: "a numeric word beside a plain one",
            code: """
            TextMorph("\\(amount) \\(unit)")
            """
        ) { UnitsDemo() }
    }
}
