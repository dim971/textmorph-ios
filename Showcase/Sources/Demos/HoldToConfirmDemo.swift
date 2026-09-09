import SwiftUI
import TextMorph

/// Upstream's thresholds, and the label each one earns.
private let holdSteps: [(Double, String)] = [
    (0, "Hold to Delete"),
    (0.12, "Holding to Delete"),
    (0.62, "Deleting"),
    (1, "Deleted")
]

/// How fast it drains when let go, as a share of the bar per second.
private let releaseRate = 0.9

private func label(at progress: Double) -> String {
    holdSteps.last { progress >= $0.0 }?.1 ?? holdSteps[0].1
}

/// A button that has to be meant.
struct HoldToConfirmDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    @State private var held = false
    @State private var auto = true

    var body: some View {
        Stage(caption: "press and hold") {
            ZStack(alignment: .leading) {
                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                Capsule()
                    .fill(Color(red: 0.95, green: 0.27, blue: 0.24))
                    .frame(width: 220 * max(0, min(1, progress)))
                TextMorph(label(at: progress), options: settings.options)
                    .textMorphFont(stageFont(size: 18))
                    .frame(width: 220)
            }
            .frame(width: 220, height: 48)
            .clipShape(.capsule)
            .contentShape(.rect)
            .gesture(hold, including: live ? .all : .none)
        }
        // Autoplay runs the whole gesture, holds on the finished state, and
        // starts over. A card that only moved under a finger would be a blank
        // in the catalogue.
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.6))
                guard !Task.isCancelled, auto else { continue }
                held = true
            }
        }
        .task(id: held) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                if held {
                    progress = min(1, progress + 0.016 / 1.6)
                    if progress == 1, auto { held = false }
                } else if progress < 1 {
                    progress = max(0, progress - 0.016 * releaseRate)
                } else {
                    try? await Task.sleep(for: .milliseconds(900))
                    progress = 0
                }
            }
        }
    }

    private var hold: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                auto = false
                held = true
            }
            .onEnded { _ in held = false }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "hold",
            name: "Hold to confirm",
            summary: "Hold to Delete, Holding to Delete, Deleting, Deleted. Four labels "
                + "crossed at four points of one gesture, and each morph starts wherever the "
                + "last one had got to, because letting go part way drains the bar back "
                + "through the same thresholds in reverse. Hold is the survivor between the "
                + "first two, and Delet is the survivor through all four.",
            capability: "a morph reversed mid-flight by a gesture",
            code: """
            TextMorph(holdSteps.last { progress >= $0.0 }?.1 ?? "")
            """
        ) { HoldToConfirmDemo() }
    }
}
