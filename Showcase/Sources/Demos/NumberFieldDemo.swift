import SwiftUI
import TextMorph

/// A field being typed into, where the caret says where the edit was.
struct NumberFieldDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var entry = "1204"
    @State private var caret: Int?

    private var amount: Double { Double(entry) ?? 0 }

    var body: some View {
        VStack(spacing: 16) {
            TextMorph(
                amount,
                options: settings.options(decimals: 0),
                cursorIndex: caret
            )
            .textMorphFont(.system(size: 40, weight: .semibold))

            TextField("Amount", text: $entry)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .onChange(of: entry) { _, new in
                    // Where the edit was. Without it the digits realign by
                    // column, which is the wrong answer for a field: the
                    // reader is watching the keystroke, not the magnitude.
                    caret = new.count
                    entry = String(new.filter(\.isNumber).prefix(9))
                }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "field",
            name: "Number field",
            summary: "Type into it. With a caret the digits either side of the edit hold their "
                + "identity and only the keystroke is new; without one they realign by column, "
                + "which is right for a magnitude and wrong for a field. Carrying 123 to 1,234 "
                + "is a two-character delta of which the reader typed one.",
            capability: "caret matching instead of place matching",
            code: """
            TextMorph(amount, cursorIndex: caret)

            TextField("Amount", text: $entry)
                .onChange(of: entry) { _, new in caret = new.count }
            """
        ) { NumberFieldDemo() }
    }
}
