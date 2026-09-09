import SwiftUI
import TextMorph

private let glued = ["819K", "990K", "9.9M", "19.4M"]
private let spaced = ["910 KB", "1.2 MB", "12 MB", "1.25 GB"]

/// A quantity glued to its unit, beside one separated from it.
struct UnitsDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: glued.count, interval: 1.6) { index in
            Stage {
                SplitRow(separator: "-") {
                    TextMorph(glued[index], options: settings.options)
                        .textMorphFont(stageFont(size: 30))
                } right: {
                    TextMorph(spaced[index], options: settings.options)
                        .textMorphFont(stageFont(size: 30))
                }
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "units",
            name: "Units",
            summary: "819K on the left, 910 KB on the right, and the space between the number "
                + "and the unit is the whole difference. Glued, the token is one word and the "
                + "letter travels with the digits; separated, it is two words and the unit "
                + "morphs on its own while the quantity rolls by place value.",
            capability: "a space deciding whether a unit belongs to the number",
            code: """
            TextMorph("9.9M")     // one word
            TextMorph("12 MB")    // two, and only the first rolls
            """
        ) { UnitsDemo() }
    }
}
