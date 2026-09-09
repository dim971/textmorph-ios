import SwiftUI
import TextMorph

/// Every option, in one place, over one value.
///
/// The catalogue answers "what can it do"; this answers "what does this option
/// do", which is a different question and needs the same value under both
/// settings rather than two different demos.
struct PlaygroundScreen: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var cycle = Cycle(["$1,204.00", "$1,318.50", "$942.75", "Total unknown"])

    var body: some View {
        NavigationStack {
            Form {
                sample
                motion
                whatMorphs
                inspecting
            }
            .navigationTitle("Playground")
        }
    }

    private var sample: some View {
        Section {
            Tappable(hint: "Tap to change the value") {
                TextMorph(cycle.current, options: settings.options)
                    .textMorphFont(.system(size: 34, weight: .semibold))
                    .padding(.vertical, 24)
            } advance: {
                cycle.advance()
            }
        }
    }

    private var motion: some View {
        Section {
            Toggle("Spring", isOn: Binding(
                get: { settings.useSpring }, set: { settings.useSpring = $0 }
            ))
            if settings.useSpring {
                slider("Stiffness", value: Binding(
                    get: { settings.stiffness }, set: { settings.stiffness = $0 }
                ), in: 20 ... 400, format: "%.0f")
                slider("Damping", value: Binding(
                    get: { settings.damping }, set: { settings.damping = $0 }
                ), in: 1 ... 40, format: "%.0f")
            } else {
                slider("Duration", value: Binding(
                    get: { settings.duration }, set: { settings.duration = $0 }
                ), in: 80 ... 2000, format: "%.0f ms")
            }
        } header: {
            Text("Motion")
        } footer: {
            Text(settings.useSpring
                ? "A spring settles on its own physics, so the duration is ignored. Damping of "
                + "exactly twice the root of the stiffness is critical, and the port fixes an "
                + "upstream bug there."
                : "The default curve is a long ease out, so most of a morph happens in its first "
                + "quarter.")
        }
    }

    private var whatMorphs: some View {
        Section {
            Toggle("Numbers by place value", isOn: Binding(
                get: { settings.numbers }, set: { settings.numbers = $0 }
            ))
            Toggle("Scale what leaves", isOn: Binding(
                get: { settings.scale }, set: { settings.scale = $0 }
            ))
        } header: {
            Text("What morphs")
        } footer: {
            Text("With numbers off, a quantity morphs character by character like any other "
                + "word. Watch the digits stop rolling.")
        }
    }

    private var inspecting: some View {
        Section {
            Toggle("Debug boxes", isOn: Binding(
                get: { settings.debug }, set: { settings.debug = $0 }
            ))
            Toggle("Disabled", isOn: Binding(
                get: { settings.disabled }, set: { settings.disabled = $0 }
            ))
        } header: {
            Text("Inspecting")
        } footer: {
            Text("Debug outlines every segment, blue for one that stays, green for one arriving, "
                + "red for one leaving. Disabled shows the value arriving already in place, "
                + "which is also what the system reduce-motion setting does.")
        }
    }

    private func slider(
        _ label: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
