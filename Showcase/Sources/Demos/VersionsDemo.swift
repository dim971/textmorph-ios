import SwiftUI
import TextMorph

/// A version number, which is not a quantity.
struct VersionsDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle(["v1.4.2", "v1.5.0", "v2.0.0", "v2.0.1"])

    var body: some View {
        Tappable(hint: "Tap to bump the version") {
            TextMorph(cycle.current, options: settings.options)
                .textMorphFont(.system(size: 32, weight: .semibold, design: .monospaced))
        } advance: {
            cycle.advance()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "versions",
            name: "Versions",
            summary: "A version is not a quantity, and the library knows it: a token has to start "
                + "and end with a digit and hold nothing but digits and separators to morph by "
                + "place value. So this morphs character by character, the way a date or a "
                + "product code should.",
            capability: "the strictness of the numeric-word test",
            code: """
            // "v1.4.2" is not a quantity, so it morphs per character
            TextMorph(version)
            """
        ) { VersionsDemo() }
    }
}
