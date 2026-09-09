import SwiftUI
import TextMorph

/// One demo, large, with its code and the options in force.
struct DemoScreen: View {
    let demo: Demo
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                demo.view
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 16))

                Text(demo.summary)
                    .font(.callout)

                LabeledContent("Exercises", value: demo.capability)
                    .font(.footnote)

                CodeSnippet(code: demo.code)

                OptionsSummary()
            }
            .padding()
        }
        .navigationTitle(demo.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// What the options are set to, so a screen is never puzzling on its own.
struct OptionsSummary: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Options")
                .font(.subheadline.weight(.semibold))
            Text(summary)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: String {
        var parts: [String] = []
        parts.append(settings.useSpring
            ? "ease: spring(stiffness: \(Int(settings.stiffness)), damping: \(Int(settings.damping)))"
            : "duration: \(Int(settings.duration))")
        if !settings.scale { parts.append("scale: false") }
        if !settings.numbers { parts.append("numbers: false") }
        if settings.debug { parts.append("debug: true") }
        if settings.disabled { parts.append("disabled: true") }
        return parts.joined(separator: ", ")
    }
}
