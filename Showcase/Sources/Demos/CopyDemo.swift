import SwiftUI
import TextMorph

/// Two words, one letter apart.
struct CopyDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: 2, interval: 2) { index in
            Stage {
                Chip {
                    TextMorph(index == 0 ? "Copy" : "Copied", options: settings.options)
                        .textMorphFont(stageFont())
                }
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "copy",
            name: "Copy",
            summary: "Copy becoming Copied. Four letters survive, two arrive, and the pill "
                + "grows to fit rather than jumping, because the container animates its own "
                + "width.",
            capability: "the container's width as an animated axis",
            code: """
            Chip { TextMorph(copied ? "Copied" : "Copy") }
            """
        ) { CopyDemo() }
    }
}
