import SwiftUI
import TextMorph

private let passage = """
The capital of Australia is Canberra, which sits in the Australian Capital \
Territory between Sydney and Melbourne. It was chosen in 1908 as a compromise \
between the two rival cities, and Walter Burley Griffin and Marion Mahony \
Griffin won the competition to design it. Their plan set the city around a \
lake and a grid of axes and circles, and today it holds Parliament House, the \
High Court, and the National Gallery.
"""

private let words = passage.split(separator: " ").map(String.init)

private let wordInterval = 0.11

/// A beat on the finished passage before it starts over.
private let holdInterval = 2.4

/// A passage arriving a word at a time, the way a model writes it.
struct StreamingDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var count = 1

    var body: some View {
        Stage {
            TextMorph(
                wrap(words.prefix(count).joined(separator: " "), 28),
                options: settings.options
            )
            .textMorphFont(stageFont(size: 17, weight: .regular))
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else {
                count = words.count
                return
            }
            while !Task.isCancelled {
                let done = count >= words.count
                try? await Task.sleep(for: .seconds(done ? holdInterval : wordInterval))
                guard !Task.isCancelled else { return }
                count = done ? 1 : count + 1
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "streaming",
            name: "Streaming",
            summary: "Seventy words arriving one at a time, nine a second, against a morph "
                + "that takes four hundred milliseconds. Every word after the first interrupts "
                + "a morph in flight, and the passage reflows as it grows because the line "
                + "breaks are recomputed each time. The words already on screen hold still "
                + "through all of it.",
            capability: "morphs arriving faster than they settle, over a reflowing value",
            code: """
            // there is no automatic wrapping, so the demo says where the lines go
            TextMorph(wrap(words.prefix(count).joined(separator: " "), 28))
            """
        ) { StreamingDemo() }
    }
}
