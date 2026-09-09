import SwiftUI
import TextMorph

private let zones = [
    "North End", "The Harbour", "Old Town",
    "Riverside", "The Docks", "Hillside"
]

private let columns = 3
private let cellWidth = 104.0
private let cellHeight = 62.0

/// A label that follows the cell it names.
struct TrailingTagDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var zone = 1
    @State private var autoplay = Autoplay()

    var body: some View {
        Stage(caption: autoplay.isPlaying ? "tap a zone" : zones[zone]) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0 ..< zones.count / columns, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0 ..< columns, id: \.self) { column in
                                let index = row * columns + column
                                Text(zones[index])
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: cellWidth, height: cellHeight)
                                    .contentShape(.rect)
                                    .onTapGesture {
                                        guard live else { return }
                                        autoplay.takeOver()
                                        zone = index
                                    }
                            }
                        }
                    }
                }
                // The tag, riding to whichever cell is current. Upstream drifts
                // it on a lissajous so it visits every zone; here it walks them
                // in order, and a tap takes it over.
                TextMorph(zones[zone], options: settings.options)
                    .textMorphFont(stageFont(size: 15))
                    .textMorphColour(.black.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor, in: .rect(cornerRadius: 8))
                    .frame(width: cellWidth, height: cellHeight)
                    .offset(
                        x: cellWidth * Double(zone % columns),
                        y: cellHeight * Double(zone / columns)
                    )
                    .animation(.interpolatingSpring(mass: 1, stiffness: 220, damping: 21), value: zone)
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "tag",
            name: "Trailing tag",
            summary: "A tag that travels to the cell it names while the name itself morphs. "
                + "Two journeys at once again, and this one crosses in two directions: The "
                + "Harbour to Riverside moves the pill diagonally while the words underneath "
                + "it have almost nothing in common. The word The survives between three of "
                + "the six, which is the only thing holding those morphs together.",
            capability: "a morph inside a container travelling in two axes",
            code: """
            TextMorph(zones[zone])
                .offset(x: x, y: y)
            """
        ) { TrailingTagDemo() }
    }
}
