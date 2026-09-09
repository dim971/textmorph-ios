import SwiftUI
import TextMorph

// Fixed, so the value is the same every run. Upstream keeps it fixed so its
// server and its first client paint agree; here it is fixed so a screenshot is
// reproducible.
private let deposit = 1204.42172398
private let apy = 0.0418
private let perSecond = (deposit * apy) / 31_536_000

/// Eight fraction digits, because a per-second rate is invisible at two.
///
/// Grouped by hand rather than by a formatter, so the string is the one the
/// Kotlin twin shows rather than the one this device's locale would.
private func money(_ value: Double) -> String {
    let text = String(format: "%.8f", value)
    let parts = text.split(separator: ".")
    let whole = Int(parts[0]) ?? 0
    return "\(grouped(whole)).\(parts.count > 1 ? String(parts[1]) : "")"
}

/// A balance accruing interest every second.
struct EarnedDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var earned = 0.0

    var body: some View {
        Stage(caption: "4.18% APY, accruing every second") {
            TextMorph(
                "$\(money(deposit + earned))",
                options: settings.options(ease: ShowcaseSettings.upstreamSpring)
            )
            .textMorphFont(stageFont(size: 26, design: .monospaced))
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            let started = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                earned = Date().timeIntervalSince(started) * perSecond
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "earned",
            name: "Earned",
            summary: "A deposit earning interest, repainted eight times a second at eight "
                + "fraction digits. Only the last few columns move, because only they changed, "
                + "and the dollars and the cents sit perfectly still through thousands of "
                + "morphs. Every one of those morphs interrupts the one before it.",
            capability: "place-value alignment under continuous interruption",
            code: """
            // repainted every 120ms against a 400ms morph
            TextMorph("$\\(money(deposit + earned))")
            """
        ) { EarnedDemo() }
    }
}
