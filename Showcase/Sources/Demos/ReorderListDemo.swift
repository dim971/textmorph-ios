import SwiftUI
import TextMorph

private let tracks = ["Ambient loops", "Field recordings", "Tape hiss"]

private let rowHeight = 46.0

/// A list whose numbers change when its rows do.
struct ReorderListDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var order = Array(tracks.indices)
    @State private var autoplay = Autoplay()

    var body: some View {
        Stage(caption: "the numbers morph, the rows slide") {
            ZStack(alignment: .top) {
                ForEach(tracks.indices, id: \.self) { track in
                    let slot = order.firstIndex(of: track) ?? 0
                    HStack(spacing: 12) {
                        TextMorph("\(slot + 1)", options: settings.options)
                            .textMorphFont(stageFont(size: 16))
                            .textMorphColour(Color.accentColor)
                        Text(tracks[track])
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 240, height: rowHeight - 6)
                    .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 10))
                    .offset(y: rowHeight * Double(slot))
                    .animation(
                        .interpolatingSpring(mass: 1, stiffness: 300, damping: 26), value: slot
                    )
                }
            }
            .frame(width: 240, height: rowHeight * Double(tracks.count), alignment: .top)
        }
        .autoplaying(autoplay, every: 2.6) {
            // One swap at a time, so exactly two numbers change and the third
            // is visibly the one that did not.
            let a = Int.random(in: 0 ..< tracks.count - 1)
            order.swapAt(a, a + 1)
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "reorder",
            name: "Reorder list",
            summary: "Two rows swap and their numbers swap with them. The rows slide, which "
                + "the layout does, and the numbers morph, which the library does, and the two "
                + "happen at once without knowing about each other. The row that did not move "
                + "keeps its number perfectly still, which is how you can tell the difference.",
            capability: "many small morphs, one per row",
            code: """
            TextMorph("\\(position + 1)")
            """
        ) { ReorderListDemo() }
    }
}
