import SwiftUI
import TextMorph

private let baseline = 7240.0

/// One slot's travel, which is both the scroll speed and the sampling rate.
private let slotSeconds = 0.42

private let window = 20

private func compact(_ value: Double) -> String {
    value >= 1000
        ? "\((value / 1000 * 10).rounded() / 10)K"
        : "\(Int(value.rounded()))"
}

private func percent(_ value: Double) -> String {
    let sign = value > 0 ? "+" : ""
    return "\(sign)\((value * 10).rounded() / 10)%"
}

/// A live figure with its recent history drawn behind it.
struct TickerDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var series = Array(repeating: baseline, count: window)
    @State private var change = 12.4

    private var rising: Bool { change >= 0 }

    private var tint: Color {
        rising
            ? Color(red: 0.29, green: 0.87, blue: 0.50)
            : Color(red: 1, green: 0.42, blue: 0.42)
    }

    var body: some View {
        Stage {
            spark
                .frame(width: 260, height: 56)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    TextMorph(compact(series.last ?? baseline), options: settings.options)
                        .textMorphFont(stageFont(size: 26))
                    Caption("requests / min")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    TextMorph(
                        percent(change),
                        options: settings.options(ease: ShowcaseSettings.upstreamSpring)
                    )
                    .textMorphFont(stageFont(size: 26))
                    .textMorphColour(tint)
                    Caption("vs. last week")
                }
            }
            .frame(width: 260)
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            var drift = 0.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(slotSeconds))
                guard !Task.isCancelled else { return }
                drift = drift * 0.8 + (Double.random(in: 0 ... 1) - 0.5) * 1.6
                let next = min(11000, max(4000, (series.last ?? baseline) + drift * 90))
                series = Array(series.dropFirst()) + [next]
                change = change * 0.9 + drift
            }
        }
    }

    private var spark: some View {
        GeometryReader { geometry in
            let low = series.min() ?? 0
            let high = series.max() ?? 1
            let span = max(1, high - low)
            // Spelled out in steps. Xcode 16.4 gives up type-checking this
            // arithmetic when it is written as two expressions inside a
            // CGPoint, and a build that only fails on the older toolchain is
            // worse than a few extra lines.
            Path { path in
                let width: Double = geometry.size.width
                let height: Double = geometry.size.height
                let last = Double(max(1, series.count - 1))
                for (index, value) in series.enumerated() {
                    let along = Double(index) / last
                    let up: Double = (value - low) / span
                    let point = CGPoint(x: width * along, y: height * (1 - up))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "ticker",
            name: "Ticker",
            summary: "A figure sampled twice a second, with its history drawn behind it and a "
                + "change that can turn negative. Two morphs on two different eases in one "
                + "card: the count on the default curve, the percentage on a spring, so the "
                + "second visibly settles after the first has arrived. Every sample interrupts "
                + "the morph before it.",
            capability: "interruption, carried momentum, and two eases at once",
            code: """
            TextMorph(compact(requests))
            TextMorph(percent(change), options: TextMorphOptions(
                ease: .spring(stiffness: 150, damping: 19, mass: 1.2)
            ))
            """
        ) { TickerDemo() }
    }
}
