import SwiftUI
import TextMorph

private let budget = 1000
private let splits = [0.64, 0.28, 0.5, 0.83]

/// One budget, divided two ways.
struct SplitBarDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var step = 0
    @State private var autoplay = Autoplay()

    var body: some View {
        let share = splits[step]
        let left = Int((Double(budget) * share).rounded())

        Stage(caption: "one budget, two shares") {
            HStack(spacing: 0) {
                half(
                    text: "$\(grouped(left))",
                    fill: Color.accentColor,
                    ink: Color.black.opacity(0.85)
                )
                .frame(maxWidth: .infinity)
                .layoutPriority(max(0.08, min(0.92, share)))

                half(
                    text: "$\(grouped(budget - left))",
                    fill: Color(uiColor: .tertiarySystemFill),
                    ink: .primary
                )
                .frame(maxWidth: .infinity)
                .layoutPriority(max(0.08, min(0.92, 1 - share)))
            }
            .frame(width: 260, height: 56)
            .clipShape(.rect(cornerRadius: 12))
            .animation(.easeOut(duration: 0.4), value: share)
        }
        .autoplaying(autoplay, every: 2.6) { step = (step + 1) % splits.count }
    }

    private func half(text: String, fill: Color, ink: Color) -> some View {
        ZStack {
            fill
            TextMorph(text, options: settings.options)
                .textMorphFont(stageFont(size: 20))
                .textMorphColour(ink)
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "split",
            name: "Split bar",
            summary: "A thousand divided between two shares that always add up. Both halves "
                + "change at once and in opposite directions, so one gains a column exactly as "
                + "the other loses one, and each rolls by its own place values inside a box "
                + "whose width is moving under it. That last part is the interesting bit: the "
                + "morph is measured against the box it is settling into, not the one it "
                + "started in.",
            capability: "place value inside a container that is itself resizing",
            code: """
            TextMorph(money(left))
            TextMorph(money(budget - left))
            """
        ) { SplitBarDemo() }
    }
}
