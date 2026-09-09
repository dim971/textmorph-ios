import SwiftUI
import TextMorph

/// Upstream cycles four package managers. A Swift package has one, and four
/// ways to pin a version, so that is what cycles here: the morph is the same
/// shape, one word changing at the front of a monospace line.
private let requirements = [
    ".upToNextMinor(from: \"0.1.0\")",
    ".upToNextMajor(from: \"0.1.0\")",
    ".exact(\"0.1.0\")",
    ".branch(\"main\")"
]

/// A dependency requirement, rewritten.
struct InstallDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: requirements.count, interval: 1.6) { index in
            Stage {
                HStack(spacing: 0) {
                    Text("> ")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextMorph(requirements[index], options: settings.options)
                        .textMorphFont(stageFont(size: 13, design: .monospaced))
                }
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "install",
            name: "Install",
            summary: "One word changes at the front of a monospace line and the rest holds "
                + "still. The plainest thing the word path does, and the one that shows a "
                + "fixed-pitch face keeps its grid through a morph.",
            capability: "the word path, at a fixed pitch",
            code: """
            TextMorph(requirement)
                .textMorphFont(.system(size: 13, design: .monospaced))
            """
        ) { InstallDemo() }
    }
}
