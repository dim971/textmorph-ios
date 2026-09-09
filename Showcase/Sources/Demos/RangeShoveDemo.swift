import SwiftUI
import TextMorph

/// Units held between the thumbs, so both stay grabbable. Upstream's number.
private let shoveGap = 8

private let presets = [(32, 68), (12, 30), (55, 91), (40, 52)]

/// Two values that have to make room for each other.
struct RangeShoveDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var preset = 0
    @State private var taken: (Int, Int)?
    @State private var autoplay = Autoplay()

    private var range: (Int, Int) { taken ?? presets[preset] }

    var body: some View {
        let lo = range.0
        let hi = range.1
        var handler: ((Int, Double) -> Void)?
        if live {
            handler = { index, fraction in set(index, fraction) }
        }

        return Stage(caption: autoplay.isPlaying ? "drag either thumb" : "range") {
            RangeTrack(
                fractions: [Double(lo) / 100, Double(hi) / 100],
                onFraction: handler,
                bubbles: [bubble(lo), bubble(hi)]
            )
            // Keyed on the preset, not the values: the presets glide and a
            // drag does not, for the same reason as the single slider.
            .animation(.easeOut(duration: 0.3), value: preset)
        }
        .autoplaying(autoplay, every: 2.2) { preset = (preset + 1) % presets.count }
    }

    private func bubble(_ value: Int) -> AnyView {
        AnyView(
            TextMorph("$\(value)", options: settings.options)
                .textMorphFont(stageFont(size: 20))
                .textMorphColour(onTint(settings.tint.colour))
        )
    }

    private func set(_ index: Int, _ fraction: Double) {
        autoplay.takeOver()
        let current = range
        let value = Int((fraction * 100).rounded())
        taken = index == 0
            ? (min(value, current.1 - shoveGap), current.1)
            : (current.0, max(value, current.0 + shoveGap))
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "range",
            name: "Range shove",
            summary: "Two pills on one track, each morphing its own value, and each in the "
                + "other's way. Drag them together and they pivot apart about their tail tips, "
                + "because a tail stays pinned to its thumb and leaning is the only way out of "
                + "an overlap. How far they lean is found by bisecting on the daylight between "
                + "their bodies, which is upstream's own rule and the whole of this card.",
            capability: "two morphs competing for the same space",
            code: """
            RangeTrack(fractions: [lo, hi], bubbles: [
                AnyView(TextMorph(money(lo))),
                AnyView(TextMorph(money(hi)))
            ])
            """
        ) { RangeShoveDemo() }
    }
}
