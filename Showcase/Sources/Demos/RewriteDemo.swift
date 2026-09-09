import SwiftUI
import TextMorph

private let tones = [
    ("Direct", "Running late, be there soon."),
    ("Friendly", "Running a bit behind, I'll be there soon."),
    ("Professional", "I'm running a little behind, should be there soon.")
]

/// The same message, rewritten in another tone.
struct RewriteDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: tones.count, interval: 2.6) { index in
            let (tone, message) = tones[index]
            Stage(caption: "tone") {
                TextMorph(wrap(message, 26), options: settings.options)
                    .textMorphFont(stageFont(size: 17, weight: .regular))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color(uiColor: .tertiarySystemFill),
                        in: .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: 16
                        )
                    )
                TextMorph(tone, options: settings.options)
                    .textMorphFont(stageFont(size: 14))
                    .textMorphColour(Color.accentColor)
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "rewrite",
            name: "Rewrite",
            summary: "A message rewritten in another tone, with the tone's own name morphing "
                + "under it. Almost nothing survives between Direct and Professional, so most "
                + "of the bubble is a group replacement: six or more adjacent characters all "
                + "leaving stop being characters and collapse as one shape.",
            capability: "the group replacement path, over several lines",
            code: """
            TextMorph(wrap(body, 26))
            TextMorph(tone)
            """
        ) { RewriteDemo() }
    }
}
