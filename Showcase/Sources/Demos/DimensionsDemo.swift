import SwiftUI
import TextMorph

private let dimensions = [
    "320 \u{00D7} 240",
    "640 \u{00D7} 480",
    "1280 \u{00D7} 720",
    "1920 \u{00D7} 1080"
]

/// Two quantities either side of a multiplication sign.
struct DimensionsDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: dimensions.count, interval: 1.6) { index in
            Stage {
                TextMorph(
                    dimensions[index],
                    options: settings.options(ease: ShowcaseSettings.upstreamSpring)
                )
                .textMorphFont(stageFont(size: 30, design: .monospaced))
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "dimensions",
            name: "Dimensions",
            summary: "Two quantities in one value, each rolling by its own columns, with a "
                + "symbol between them that belongs to neither. Both gain a digit at 1280, so "
                + "both carry, and the multiplication sign travels the distance the left one "
                + "grew.",
            capability: "two numeric words in one value",
            code: """
            TextMorph("1280 \u{00D7} 720", options: TextMorphOptions(
                ease: .spring(stiffness: 150, damping: 19, mass: 1.2)
            ))
            """
        ) { DimensionsDemo() }
    }
}
