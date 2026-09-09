import SwiftUI
import TextMorph

private let dialMax = 500

/// Degrees of dial per unit of value, so the whole range is most of a turn.
private let stepDegrees = 0.6

private let dialPresets = [75, 240, 18, 410]

/// A number on a dial, settling on a spring.
struct SpinDialDemo: View {
    @Environment(ShowcaseSettings.self) private var settings
    @Environment(\.showcaseInteractive) private var live
    @State private var preset = 0
    @State private var turned: Double?
    @State private var lastAngle = 0.0
    @State private var autoplay = Autoplay()

    private var value: Int {
        max(0, min(dialMax, Int((turned ?? Double(dialPresets[preset])).rounded())))
    }

    var body: some View {
        let caption = autoplay.isPlaying ? "drag around the dial" : "\(value) of \(dialMax)"

        return Stage(caption: caption) {
            ZStack {
                ticks
                TextMorph(
                    "$\(value)",
                    options: settings.options(ease: ShowcaseSettings.upstreamSpring)
                )
                .textMorphFont(stageFont(size: 36))
            }
            .frame(width: 180, height: 180)
            .contentShape(.rect)
            .gesture(dial, including: live ? .all : .none)
        }
        .autoplaying(autoplay, every: 2.6) { preset = (preset + 1) % dialPresets.count }
    }

    private var ticks: some View {
        Canvas { context, size in
            // Spelled out in steps rather than in one expression. Xcode 16.4
            // gives up type-checking the nested arithmetic inside a Canvas
            // closure, and a build that only fails on the older toolchain is
            // worse than a few extra lines.
            let radius: Double = min(size.width, size.height) / 2 - 8
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let count = 60
            let share = Double(value) / Double(dialMax)
            let lit = Int((share * Double(count)).rounded())
            for i in 0 ..< count {
                // Starting at the bottom and going clockwise, so an empty dial
                // reads as empty rather than as half full.
                let turn = Double(i) / Double(count)
                let a = Double.pi / 2 + turn * 2 * Double.pi
                let inner: Double = radius - (i < lit ? 16 : 10)
                var path = Path()
                path.move(to: CGPoint(
                    x: centre.x + cos(a) * inner, y: centre.y + sin(a) * inner
                ))
                path.addLine(to: CGPoint(
                    x: centre.x + cos(a) * radius, y: centre.y + sin(a) * radius
                ))
                context.stroke(
                    path,
                    // Visible against the card, which a fill colour is not.
                    with: .color(i < lit ? Color.accentColor : Color.primary.opacity(0.18)),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
            }
        }
    }

    private var dial: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                autoplay.takeOver()
                if turned == nil {
                    turned = Double(value)
                    lastAngle = atan2(drag.startLocation.y - 90, drag.startLocation.x - 90)
                }
                let angle = atan2(drag.location.y - 90, drag.location.x - 90)
                var delta = angle - lastAngle
                // Across the seam, the short way round is the right way.
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                lastAngle = angle
                let degrees: Double = delta * 180 / Double.pi
                let next: Double = (turned ?? 0) + degrees / stepDegrees
                turned = max(0, min(Double(dialMax), next))
            }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "spin",
            name: "Spin dial",
            summary: "Drag around the dial. The value is driven by an angle, so it arrives in "
                + "a rush and settles on a spring, and a spring is the one ease that ignores "
                + "the duration entirely: it takes as long as its own physics say. It also "
                + "overshoots, which is why a morph is allowed to draw outside its own box.",
            capability: "a spring, and the overshoot the drawing surface allows for",
            code: """
            TextMorph(money(value), options: TextMorphOptions(
                ease: .spring(stiffness: 150, damping: 19, mass: 1.2)
            ))
            """
        ) { SpinDialDemo() }
    }
}
