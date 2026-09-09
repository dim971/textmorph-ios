import SwiftUI
import TextMorph

/// The catalogue: every demo, running, with what it is for.
struct CatalogScreen: View {
    /// A demo to open straight away, for a screenshot script.
    var openDemo: String?

    @Environment(ShowcaseSettings.self) private var settings
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(Catalog.demos) { demo in
                        NavigationLink(value: demo.id) {
                            row(demo)
                        }
                    }
                } footer: {
                    Text("Every demo runs under the options in Playground, "
                        + "so the way to understand one is to change an option and watch it again.")
                }
            }
            .navigationTitle("TextMorph")
            .onAppear {
                if let openDemo, path.isEmpty { path = [openDemo] }
            }
            .navigationDestination(for: String.self) { id in
                if let demo = Catalog.demos.first(where: { $0.id == id }) {
                    DemoScreen(demo: demo)
                }
            }
        }
    }

    private func row(_ demo: Demo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(demo.name)
                    .font(.headline)
                Spacer()
                Text(demo.capability)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            // Running, not a still. A catalogue of morphing text that does not
            // morph in the list is a catalogue of screenshots. Clipped,
            // because a morph is allowed to overflow its container and a row
            // that overflows drags the whole list sideways.
            demo.view
                .frame(maxWidth: .infinity, minHeight: 44)
                .clipped()
                .environment(\.showcaseAutoAdvance, true)
                // A row lives inside a scrolling list, and a demo that grabs a
                // drag there eats the scroll. So the previews run themselves
                // and answer to nothing.
                .environment(\.showcaseInteractive, false)
            Text(demo.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
