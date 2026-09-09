import SwiftUI
import TextMorph

private let script = "1234567.89"
private let typeInterval = 0.22

/// A beat on the formatted total before it clears and starts over.
private let holdInterval = 1.8

/// The digits so far, grouped the way a field would show them.
private func formatted(_ typed: String) -> String {
    if typed.isEmpty { return "0" }
    let parts = typed.split(separator: ".", omittingEmptySubsequences: false)
    let whole = grouped(Int(parts[0]) ?? 0)
    guard typed.contains(".") else { return whole }
    return "\(whole).\(parts.count > 1 ? String(parts[1]) : "")"
}

/// A field being typed into, where the caret says where the edit was.
struct NumoraFieldDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typed = 0

    var body: some View {
        let value = formatted(String(script.prefix(typed)))

        Stage(caption: "typing, with the caret passed in") {
            HStack(spacing: 2) {
                // The caret is at the end of what has been typed, and the whole
                // point of passing it is that the digits either side hold their
                // identity instead of realigning by column.
                TextMorph(
                    value,
                    options: settings.options(decimals: nil),
                    cursorIndex: value.utf16.count
                )
                .textMorphFont(stageFont(size: 30, design: .monospaced))
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 30)
            }
            .frame(width: 240, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .tertiarySystemFill))
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else {
                typed = script.count
                return
            }
            while !Task.isCancelled {
                let done = typed >= script.count
                try? await Task.sleep(for: .seconds(done ? holdInterval : typeInterval))
                guard !Task.isCancelled else { return }
                typed = done ? 0 : typed + 1
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "field",
            name: "Number field",
            summary: "A number typed one character at a time, with the caret handed to the "
                + "morph. Every keystroke pushes a grouping separator along, so without a "
                + "caret the digits would realign by column and half of them would slide a "
                + "place on every press. With one, both sides of the edit hold their identity "
                + "and only the keystroke is new.",
            capability: "caret matching instead of place matching",
            code: """
            TextMorph(formatted(typed), cursorIndex: caret)
            """
        ) { NumoraFieldDemo() }
    }
}
