import SwiftUI
import TextMorph

/// What this is, and what it is a port of.
struct AboutScreen: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        TextMorph("TextMorph")
                            .textMorphFont(.textStyle(.largeTitle))
                        Text("Text continuity for SwiftUI.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("What it is") {
                    Text("A native SwiftUI port of Torph, by Lochie Axon. When a value changes, "
                        + "the characters, words and digits that survive the change move to "
                        + "their new place instead of disappearing in a cross-fade.")
                    Text("The engine is pinned to the JavaScript original by fixtures generated "
                        + "from the published package, so a change of behaviour here is a "
                        + "failing test rather than a discovery.")
                }

                Section("Links") {
                    Link("Torph", destination: URL(string: "https://torph.lochie.me")!)
                    Link(
                        "textmorph-ios",
                        destination: URL(string: "https://github.com/dim971/textmorph-ios")!
                    )
                    Link(
                        "textmorph-android",
                        destination: URL(string: "https://github.com/dim971/textmorph-android")!
                    )
                }

                Section("Licence") {
                    Text("MIT. Torph is MIT, copyright 2025 Lochie Axon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("About")
        }
    }
}
