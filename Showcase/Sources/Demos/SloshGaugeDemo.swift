import SwiftUI
import TextMorph

private let levels = [0.72, 0.52, 0.95, 0.46]

/// A tank filling and emptying, with its level written across it.
struct SloshGaugeDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var step = 0
    @State private var autoplay = Autoplay()

    var body: some View {
        let level = levels[step]
        let value = "\(Int((level * 100).rounded()))%"

        Stage(caption: "level") {
            ZStack {
                Color(uiColor: .tertiarySystemFill)
                // The liquid, filling from the bottom.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Color.accentColor.frame(height: 96 * level)
                }
                // The value twice: once in the ink colour, and once in a dark
                // one clipped to the liquid, so the digits under the surface
                // read against it rather than through it. Upstream clips the
                // same value to the same surface.
                TextMorph(value, options: settings.options)
                    .textMorphFont(stageFont(size: 30))
                TextMorph(value, options: settings.options)
                    .textMorphFont(stageFont(size: 30))
                    .textMorphColour(.black.opacity(0.85))
                    .mask(alignment: .bottom) {
                        Color.black.frame(height: 96 * level)
                    }
            }
            .frame(width: 150, height: 96)
            .clipShape(.rect(cornerRadius: 14))
            .animation(.interpolatingSpring(mass: 1, stiffness: 90, damping: 10), value: level)
        }
        .autoplaying(autoplay, every: 2.6) { step = (step + 1) % levels.count }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "slosh",
            name: "Slosh gauge",
            summary: "A level written across the thing it measures. The same value is drawn "
                + "twice, once in the ink colour and once in a dark one clipped to the liquid, "
                + "so the digits under the surface read against it. Two morphs of the same "
                + "value, in step because they are given the same value at the same moment "
                + "rather than because anything synchronises them.",
            capability: "two morphs of one value, layered",
            code: """
            TextMorph(level)                    // above the surface
            TextMorph(level)                    // below it
                .textMorphColour(.black)
                .mask(alignment: .bottom) { Color.black.frame(height: surface) }
            """
        ) { SloshGaugeDemo() }
    }
}
