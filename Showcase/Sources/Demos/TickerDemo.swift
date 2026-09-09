import SwiftUI
import TextMorph

/// A value that changes faster than the morph settles.
struct TickerDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @State private var price = 128.44

    var body: some View {
        Ticking(interval: 0.12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextMorph(price, options: settings.options(decimals: 2))
                    .textMorphFont(.system(size: 36, weight: .semibold, design: .monospaced))
                Text("USD")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } advance: {
            price = max(80, min(180, price + Double.random(in: -1.2 ... 1.2))).rounded(to: 2)
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "ticker",
            name: "Ticker",
            summary: "A new value every eighth of a second, against a morph that takes four "
                + "hundred milliseconds. Each morph is interrupted by the next and carries on "
                + "from where it had got to, and the box resumes its curve rather than replaying "
                + "the opening sliver of it. Without that the digits race and the box crawls.",
            capability: "interruption, carried momentum, and the container resuming",
            code: """
            // updated every 120ms, against a 400ms morph
            TextMorph(price, options: TextMorphOptions(decimals: 2))
            """
        ) { TickerDemo() }
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
