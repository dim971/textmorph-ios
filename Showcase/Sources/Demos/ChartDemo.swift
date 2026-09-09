import SwiftUI
import TextMorph

private let months: [(String, Int)] = [
    ("January", 4120), ("February", 3840), ("March", 5230), ("April", 4780),
    ("May", 6150), ("June", 5890), ("July", 7240), ("August", 6870),
    ("September", 7590), ("October", 8120), ("November", 7430), ("December", 9210)
]

private let peak = months.map(\.1).max() ?? 1

/// A figure scrubbed out of a chart.
struct ChartDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var month = 4
    @State private var autoplay = Autoplay()

    var body: some View {
        let (name, value) = months[month]
        Stage(caption: autoplay.isPlaying ? "drag across the bars" : "scrubbing") {
            TextMorph(
                "$\(grouped(value))",
                options: settings.options(ease: ShowcaseSettings.upstreamSpring)
            )
            .textMorphFont(stageFont(size: 34))

            // A hundred milliseconds, because the label is following a finger
            // and anything slower reads as lag rather than as motion.
            // Upstream's number.
            TextMorph(
                "\(name) revenue",
                options: settings.options(ease: settings.options.ease, duration: 100)
            )
            .textMorphFont(stageFont(size: 14, weight: .regular))
            .textMorphColour(.secondary)

            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(months.enumerated()), id: \.offset) { index, entry in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index == month ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                            .frame(height: 72 * Double(entry.1) / Double(peak))
                    }
                }
                .frame(height: 72, alignment: .bottom)
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            autoplay.takeOver()
                            let slot = Int((drag.location.x / geometry.size.width
                                    * Double(months.count)).rounded())
                            month = max(0, min(months.count - 1, slot))
                        },
                    including: live ? .all : .none
                )
            }
            .frame(width: 260, height: 72)
        }
        .autoplaying(autoplay, every: 1.3) { month = (month + 1) % months.count }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "chart",
            name: "Chart",
            summary: "Drag across the bars. Two morphs at two speeds: the amount on a spring, "
                + "which settles, and the month on a hundred milliseconds, which has to keep "
                + "up with a finger. That difference is the point of the card. A label "
                + "following a gesture on a four hundred millisecond morph reads as lag; the "
                + "amount on the same duration reads as haste.",
            capability: "two durations chosen for two jobs",
            code: """
            TextMorph(amount, options: TextMorphOptions(ease: .spring()))
            TextMorph("\\(month) revenue", options: TextMorphOptions(duration: 100))
            """
        ) { ChartDemo() }
    }
}
