import SwiftUI
import TextMorph

private let phrases = [
    "3 hours 24 minutes ago",
    "3 hr 24 min ago",
    "3h 24m ago",
    "3h ago",
    "now"
]

/// A phrase abbreviating as the room runs out.
struct SqueezeToAbbreviateDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: phrases.count, interval: 3) { index in
            Stage {
                TextMorph(phrases[index], options: settings.options)
                    .textMorphFont(stageFont(size: 24, weight: .regular))
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "squeeze",
            name: "Squeeze to abbreviate",
            summary: "The same timestamp in five lengths, from a full sentence down to one "
                + "word. Every step keeps the digits and drops the words around them, so the "
                + "3 and the 24 hold their places while hours becomes hr becomes h. The last "
                + "step keeps nothing at all, and that is where the group replacement takes "
                + "over.",
            capability: "words shrinking around quantities that stay put",
            code: """
            TextMorph(phrases[step])
            """
        ) { SqueezeToAbbreviateDemo() }
    }
}
