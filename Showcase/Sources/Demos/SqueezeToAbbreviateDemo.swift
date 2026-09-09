import SwiftUI
import TextMorph

/// A number that abbreviates as it runs out of room.
struct SqueezeToAbbreviateDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var width = 220.0

    private let count = 1_204_318.0

    /// The widest form that fits.
    private var text: String {
        if width > 170 { return count.formatted(.number.locale(defaultMorphLocale)) }
        if width > 120 { return "\((count / 1000).rounded())k" }
        return "\((count / 100_000).rounded() / 10)M"
    }

    var body: some View {
        VStack(spacing: 16) {
            TextMorph(text, options: settings.options)
                .textMorphFont(.system(size: 32, weight: .semibold))
                .frame(width: width, alignment: .leading)
                .clipped()
            Slider(value: $width, in: 70 ... 240) {
                Text("Room")
            }
            .frame(maxWidth: 260)
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "squeeze",
            name: "Squeeze to abbreviate",
            summary: "Drag the slider. As the room runs out the value switches to a shorter form, "
                + "and the digits that survive the switch carry across rather than the whole "
                + "number being replaced.",
            capability: "a magnitude jump, and the cap that stops one smearing",
            code: """
            // 1,204,318 -> 1204k -> 1.2M as the room runs out
            TextMorph(abbreviated(count, fitting: width))
                .frame(width: width, alignment: .leading)
            """
        ) { SqueezeToAbbreviateDemo() }
    }
}
