import SwiftUI
import TextMorph

/// U+2212, not a hyphen: it is the width of the plus it replaces, so the digits
/// beside it do not shift when the sign changes. Upstream's own note.
private let deltas = ["+2.4%", "\u{2212}0.8%", "+11.2%", "0.0%", "\u{2212}13.6%"]

private func tone(_ value: String) -> Color {
    if value.hasPrefix("\u{2212}") { return Color(red: 1, green: 0.42, blue: 0.42) }
    if value.hasPrefix("+") { return Color(red: 0.29, green: 0.87, blue: 0.50) }
    return .primary
}

/// A signed change, where the sign is part of the morph.
struct DeltaDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: deltas.count, interval: 1.6) { index in
            Stage {
                TextMorph(
                    deltas[index],
                    options: settings.options(ease: ShowcaseSettings.upstreamSpring)
                )
                .textMorphFont(stageFont(size: 34))
                .textMorphColour(tone(deltas[index]))
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "delta",
            name: "Delta",
            summary: "A sign in front and a percent sign behind, both affixes, so they pair "
                + "off before the columns are aligned and the digits still roll by place. The "
                + "sign is U+2212 rather than a hyphen, which is upstream's choice and a good "
                + "one: it is the width of the plus it replaces, so nothing shifts when the "
                + "reading turns negative.",
            capability: "affixes at both ends, and symbols sliding from below",
            code: """
            TextMorph("\u{2212}0.8%")
                .textMorphColour(change < 0 ? .red : .green)
            """
        ) { DeltaDemo() }
    }
}
