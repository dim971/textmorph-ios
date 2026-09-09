import SwiftUI
import TextMorph

private let versions = ["v1.2.3", "v1.3.0", "v2.0.0", "v2.0.1"]

/// A version number, which is not a quantity.
struct VersionsDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: versions.count, interval: 1.4) { index in
            Stage {
                TextMorph(versions[index], options: settings.options)
                    .textMorphFont(stageFont(size: 30, design: .monospaced))
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "versions",
            name: "Versions",
            summary: "A version is not a quantity, and the library knows it: a token has to "
                + "start and end with a digit and hold nothing but digits and separators to "
                + "morph by place value. So this morphs character by character, the way a "
                + "date or a product code should.",
            capability: "the strictness of the numeric-word test",
            code: """
            // "v1.2.3" is not a quantity, so it morphs per character
            TextMorph(version)
            """
        ) { VersionsDemo() }
    }
}
