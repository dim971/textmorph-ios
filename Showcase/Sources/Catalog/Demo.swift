import SwiftUI

/// One entry in the catalogue.
///
/// Each demo names the capability it exists to show, because a catalogue of
/// pretty animations teaches nothing: the point is to be able to look up "how
/// does a number roll" and find the one screen that answers it.
struct Demo: Identifiable {
    let id: String
    let name: String
    /// What it is, in a line.
    let summary: String
    /// The one capability of the engine it exercises.
    let capability: String
    /// The code it is, near enough to paste.
    let code: String
    /// The demo itself.
    let view: AnyView

    init(
        id: String,
        name: String,
        summary: String,
        capability: String,
        code: String,
        @ViewBuilder view: () -> some View
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.capability = capability
        self.code = code
        self.view = AnyView(view())
    }
}
