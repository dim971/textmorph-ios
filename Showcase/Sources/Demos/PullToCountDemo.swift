import SwiftUI
import TextMorph

private let pullMin = -199
private let pullMax = 999

/// Points of travel before the rubber band saturates. Upstream's number.
private let pullLimit = 74.0

/// Units per second at a full pull. Upstream's number.
private let pullRate = 30.0

/// U+2212 rather than a hyphen, so a negative reading is the width of a positive one.
private func signed(_ value: Int) -> String {
    value < 0 ? "\u{2212}\(abs(value))" : "\(value)"
}

/// A counter driven by how far it is pulled.
struct PullToCountDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var value = 0
    @State private var pull = 0.0
    @State private var held = false
    @State private var autoplay = Autoplay()

    var body: some View {
        Stage(caption: autoplay.isPlaying ? "pull it up or down" : "counting") {
            TextMorph(signed(value), options: settings.options)
                .textMorphFont(stageFont(size: 34))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 14))
                .offset(y: held ? pull * 0.5 : 0)
                .animation(.easeOut(duration: 0.2), value: held)
                .frame(width: 200, height: 120)
                .contentShape(.rect)
                .gesture(drag, including: live ? .all : .none)
        }
        .autoplaying(autoplay, every: 2) {
            value = value + 137 > pullMax ? pullMin + 40 : value + 137
        }
        // While it is held, the count runs at a rate set by the pull. That is
        // the whole gesture: a position becomes a speed.
        .task(id: held) {
            while held, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard held, !Task.isCancelled else { return }
                let rate = max(-1, min(1, pull / pullLimit)) * pullRate
                value = max(pullMin, min(pullMax, value + Int((rate * 0.016).rounded())))
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                autoplay.takeOver()
                held = true
                // Rubber band: the last few points cost more than the first,
                // so a full pull is a decision rather than a slip.
                let next = value.translation.height
                pull = next < 0
                    ? -min(-next, pullLimit * 1.4)
                    : min(next, pullLimit * 1.4)
            }
            .onEnded { _ in
                held = false
                pull = 0
            }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "pull",
            name: "Pull to count",
            summary: "Pull the card and the count runs, faster the further you pull. It "
                + "crosses zero into negatives, and the sign is U+2212 rather than a hyphen so "
                + "the reading does not shift sideways when it turns. Sixty morphs a second, "
                + "each interrupting the last, which is the same pressure the Earned card puts "
                + "on the engine and a different way of applying it.",
            capability: "a gesture driving a morph faster than it settles",
            code: """
            TextMorph(signed(count))   // U+2212 for a minus, not a hyphen
            """
        ) { PullToCountDemo() }
    }
}
