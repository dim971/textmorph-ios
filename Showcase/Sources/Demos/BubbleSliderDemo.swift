import SwiftUI
import TextMorph

/// Not named `brightness`: SwiftUI puts a modifier of that name on every
/// view, and the modifier wins the lookup inside a `View` body.
private let presets = [72, 18, 94, 41, 63]

/// A value in a pill that rides the thumb.
struct BubbleSliderDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var preset = 0
    @State private var taken: Double?
    @State private var autoplay = Autoplay()

    private var fraction: Double {
        taken ?? Double(presets[preset]) / 100
    }

    var body: some View {
        Stage(caption: autoplay.isPlaying ? "drag the thumb" : "brightness") {
            BubbleTrack(
                fraction: fraction,
                onFraction: live ? { next in
                    autoplay.takeOver()
                    taken = next
                } : nil
            ) {
                TextMorph("\(Int((fraction * 100).rounded()))%", options: settings.options)
                    .textMorphFont(stageFont(size: 20))
                    .textMorphColour(.black.opacity(0.9))
            }
            // The value eases rather than cutting, so the pill is carried by
            // the travel and the digits roll on the way.
            .animation(.easeInOut(duration: 0.7), value: fraction)
        }
        .autoplaying(autoplay, every: 1.7) { preset = (preset + 1) % presets.count }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "bubble",
            name: "Bubble slider",
            summary: "The value rides the thumb, so it is morphing inside a box that is itself "
                + "travelling. Those are two different motions and the library only owns one "
                + "of them: the pill's journey is the layout's, and the digits rolling inside "
                + "it are the morph's. Drag it slowly and the two come apart; drag it fast and "
                + "the digits are still catching up when the thumb arrives.",
            capability: "a morph inside a moving container",
            code: """
            BubbleTrack(fraction: value / 100) {
                TextMorph("\\(value)%")
            }
            """
        ) { BubbleSliderDemo() }
    }
}
