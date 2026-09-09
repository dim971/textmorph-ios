import SwiftUI
import TextMorph

/// A morph on a spring rather than a curve.
struct SpinDialDemo: View {
    @State private var value = 24.0

    /// Upstream's own spring for this example, and deliberately not the
    /// catalogue's: the point of the screen is what a spring does.
    private var options: TextMorphOptions {
        TextMorphOptions(
            ease: .spring(stiffness: 150, damping: 19, mass: 1.2),
            decimals: 0
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            TextMorph(value, options: options)
                .textMorphFont(.system(size: 44, weight: .bold, design: .rounded))
            Stepper("Value", value: $value, in: 0 ... 99)
                .labelsHidden()
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "spin",
            name: "Spin dial",
            summary: "A spring settles on its own physics and ignores the duration. It also "
                + "overshoots, which is why a morph is allowed to draw outside its own box: a "
                + "glyph clipped at the peak of its bounce is a bug that only appears here.",
            capability: "a spring, and the overshoot the surface allows for",
            code: """
            TextMorph(value, options: TextMorphOptions(
                ease: .spring(stiffness: 150, damping: 19, mass: 1.2),
                decimals: 0
            ))
            """
        ) { SpinDialDemo() }
    }
}
