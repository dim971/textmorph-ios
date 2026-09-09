import SwiftUI
import TextMorph

/// A value with no spaces in it at all.
struct HexColourDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle(["#FF6B35", "#004E89", "#1A659E", "#EFEFD0"])

    private var colour: Color {
        Color(
            red: value(0) / 255, green: value(2) / 255, blue: value(4) / 255
        )
    }

    private func value(_ offset: Int) -> Double {
        let hex = cycle.current.dropFirst()
        let start = hex.index(hex.startIndex, offsetBy: offset)
        let end = hex.index(start, offsetBy: 2)
        return Double(UInt8(hex[start ..< end], radix: 16) ?? 0)
    }

    var body: some View {
        Tappable(hint: "Tap to change the colour") {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colour)
                    .frame(width: 44, height: 44)
                TextMorph(cycle.current, options: settings.options)
                    .textMorphFont(.system(size: 28, weight: .medium, design: .monospaced))
            }
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "hex",
            name: "Hex colour",
            summary: "No spaces, so the value is cut into grapheme clusters and morphs letter by "
                + "letter. That is the path most of this library's use takes: a counter, a price "
                + "or a code is one word.",
            capability: "the grapheme path of the segmenter",
            code: """
            TextMorph(hex)
                .textMorphFont(.system(size: 28, weight: .medium, design: .monospaced))
            """
        ) { HexColourDemo() }
    }
}
