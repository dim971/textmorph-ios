import SwiftUI
import TextMorph

/// Fixed saturation and lightness, so the swatches move hue alone. Upstream's
/// own conversion, transcribed rather than replaced by a Color(hue:) call,
/// because the string it produces is the value being morphed and a different
/// rounding would change which characters survive.
private func channel(_ n: Int, _ hue: Int) -> String {
    let k = (Double(n) + Double(hue) / 30).truncatingRemainder(dividingBy: 12)
    let c = 0.5 - 0.35 * max(-1, min(min(k - 3, 9 - k), 1))
    return String(format: "%02X", Int((c * 255).rounded()))
}

private func hex(_ hue: Int) -> String {
    "#\(channel(0, hue))\(channel(8, hue))\(channel(4, hue))"
}

private let hues = (0 ..< 12).map { $0 * 30 }

private func colour(_ value: String) -> Color {
    let scanner = UInt32(value.dropFirst(), radix: 16) ?? 0
    return Color(
        red: Double((scanner >> 16) & 0xFF) / 255,
        green: Double((scanner >> 8) & 0xFF) / 255,
        blue: Double(scanner & 0xFF) / 255
    )
}

/// A value with no spaces in it at all.
struct HexColourDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var hue = 0

    var body: some View {
        Stage {
            TextMorph(hex(hue), options: settings.options)
                .textMorphFont(stageFont(size: 30, design: .monospaced))
                .textMorphColour(colour(hex(hue)))
            HStack(spacing: 6) {
                ForEach(hues, id: \.self) { h in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colour(hex(h)))
                        .frame(width: 22, height: 22)
                        .onTapGesture { if live { hue = h } }
                }
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "hex",
            name: "Hex colour",
            summary: "No spaces, so the value is cut into grapheme clusters and morphs letter "
                + "by letter. That is the path most of this library's use takes: a counter, a "
                + "price or a code is one word. Tap a swatch and watch which characters "
                + "survive: two colours a third of the wheel apart still share digits.",
            capability: "the grapheme path of the segmenter",
            code: """
            TextMorph(hex)
                .textMorphFont(.system(size: 30, design: .monospaced))
            """
        ) { HexColourDemo() }
    }
}
