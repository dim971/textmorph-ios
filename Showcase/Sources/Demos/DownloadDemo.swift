import SwiftUI
import TextMorph

/// How long a run takes, and the beat either side of it. Upstream's numbers.
private let runSeconds = 2.0
private let idleSeconds = 0.9
private let doneSeconds = 1.6

private let barWidth = 220.0

/// A label that counts, then stops counting.
struct DownloadDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = -1.0

    private var label: String {
        if progress < 0 { return "Download" }
        if progress >= 1 { return "Downloaded" }
        return "\(Int((progress * 100).rounded()))%"
    }

    var body: some View {
        Stage(caption: "a word, then a count, then a word") {
            TextMorph(label, options: settings.options)
                .textMorphFont(stageFont(size: 26))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: barWidth, height: 6)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: barWidth * max(0, min(1, progress)), height: 6)
            }
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                progress = -1
                try? await Task.sleep(for: .seconds(idleSeconds))
                let started = Date()
                while !Task.isCancelled {
                    let t = min(1, Date().timeIntervalSince(started) / runSeconds)
                    // Accelerating rather than linear, so the percentages
                    // arrive slowly at first and the morph has time to be seen.
                    progress = t * t
                    if t >= 1 { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                try? await Task.sleep(for: .seconds(doneSeconds))
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "download",
            name: "Download",
            summary: "Download, then a percentage counting up, then Downloaded. The "
                + "interesting part is the two boundaries: a word becoming a number has "
                + "nothing in common with it, so that is a replacement, while the numbers "
                + "between roll by place value. Three kinds of morph in one four-second loop, "
                + "and the label never jumps width because the container carries it.",
            capability: "a word, a quantity and a word again, in one place",
            code: """
            TextMorph(idle ? "Download" : done ? "Downloaded" : "\\(percent)%")
            """
        ) { DownloadDemo() }
    }
}
