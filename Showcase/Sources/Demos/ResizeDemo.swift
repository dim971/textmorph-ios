import SwiftUI
import TextMorph

/// Not named `body`: that is the view's own property, and a demo whose
/// constant shadows it compiles into something surprising.
private let sentence = "Drag the handle to rewrap this sentence."

private let minWidth = 68.0
private let maxWidth = 208.0

/// Where autoplay parks the handle, until someone takes it.
private let stops = [maxWidth, 140.0, minWidth, 140.0]

/// How many characters fit at a width.
///
/// A rough conversion rather than a measurement, and deliberately: the demo is
/// about a value that gains and loses lines, not about a text engine. Roughly
/// six and a half points to a character at this size.
private func chars(at width: Double) -> Int {
    max(4, Int((width / 6.5).rounded()))
}

/// A sentence that rewraps as its column narrows.
struct ResizeDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var stop = 0
    @State private var dragged: Double?
    @State private var autoplay = Autoplay()

    private var width: Double { dragged ?? stops[stop] }

    var body: some View {
        Stage(caption: autoplay.isPlaying ? "drag the handle" : "\(Int(width.rounded()))pt") {
            HStack(alignment: .top, spacing: 0) {
                TextMorph(wrap(sentence, chars(at: width)), options: settings.options)
                    .textMorphFont(stageFont(size: 15, weight: .regular))
                    .multilineTextAlignment(.leading)
                    .padding(10)
                    .frame(width: width, alignment: .topLeading)
                    .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 10))

                // The handle. Dragging it takes the column over from autoplay,
                // which is upstream's rule everywhere: a demo hands over rather
                // than fighting the finger.
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 44)
                    .contentShape(.rect)
                    .gesture(handle, including: live ? .all : .none)
            }
            .animation(.easeOut(duration: 0.35), value: width)
        }
        .autoplaying(autoplay, every: 2.6) { stop = (stop + 1) % stops.count }
    }

    private var handle: some Gesture {
        DragGesture()
            .onChanged { drag in
                autoplay.takeOver()
                let from = dragged ?? width
                dragged = max(minWidth, min(maxWidth, from + drag.translation.width))
            }
            .onEnded { _ in dragged = width }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "resize",
            name: "Resize",
            summary: "Drag the handle. The sentence rewraps, so words move between lines, and "
                + "a word that changes line travels diagonally to its new place instead of "
                + "disappearing from one row and appearing on another. There is no automatic "
                + "wrapping in the library: the demo computes the breaks and passes them in, "
                + "which is exactly why the morph can see that a word survived.",
            capability: "a value gaining and losing lines",
            code: """
            // the library never wraps, so the caller decides where the lines go
            TextMorph(wrap(sentence, chars(at: width)))
            """
        ) { ResizeDemo() }
    }
}
