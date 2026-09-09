import SwiftUI
import TextMorph

private let ratings: [(String, Color)] = [
    ("Abysmal", Color(red: 0.95, green: 0.27, blue: 0.24)),
    ("Awful", Color(red: 1, green: 0.48, blue: 0.18)),
    ("Alright", Color(red: 0.94, green: 0.71, blue: 0.16)),
    ("Amazing", Color(red: 0.23, green: 0.51, blue: 0.96)),
    ("Astonishing", Color(red: 0.20, green: 0.78, blue: 0.35))
]

/// Five words that all begin with an A.
struct RatingSliderDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var index = 0
    @State private var autoplay = Autoplay()

    var body: some View {
        let (word, tone) = ratings[index]
        Stage(caption: autoplay.isPlaying ? "drag to rate" : "rating") {
            BubbleTrack(
                fraction: Double(index) / Double(ratings.count - 1),
                // The pill takes the rating's colour and the word goes dark on
                // it, rather than the other way round: five tones on one accent
                // would have two of them unreadable.
                bubbleColour: tone,
                onFraction: live ? { next in
                    autoplay.takeOver()
                    index = Int((next * Double(ratings.count - 1)).rounded())
                } : nil
            ) {
                TextMorph(word, options: settings.options)
                    .textMorphFont(stageFont(size: 20))
                    .textMorphColour(.black.opacity(0.9))
            }
            .animation(.easeOut(duration: 0.3), value: index)
        }
        .autoplaying(autoplay, every: 1.8) { index = (index + 1) % ratings.count }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "rating",
            name: "Rating slider",
            summary: "Abysmal, Awful, Alright, Amazing, Astonishing. Every one of them starts "
                + "with an A, and the A never moves: it is the survivor the rest of the word "
                + "is measured against. Watch the second letter instead, which is where each "
                + "morph actually happens.",
            capability: "a shared first character anchoring five different words",
            code: """
            BubbleTrack(fraction: Double(index) / 4, bubbleColour: tone) {
                TextMorph(word)
            }
            """
        ) { RatingSliderDemo() }
    }
}
