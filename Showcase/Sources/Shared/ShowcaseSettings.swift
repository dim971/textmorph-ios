import Observation
import SwiftUI
import TextMorph

/// The options every demo runs under, so one switch changes the whole catalog.
///
/// A morph is a transition, so the way to understand an option is to watch the
/// same demo with it on and off. Putting the options in one place, reachable
/// from every screen, is the difference between a catalogue and a gallery.
@Observable
final class ShowcaseSettings {
    var duration = 400.0
    var useSpring = false
    var stiffness = 100.0
    var damping = 10.0
    var scale = true
    var numbers = true
    var debug = false
    var disabled = false

    /// The colour the tinted cards are drawn in.
    ///
    /// Global rather than per card, so changing it in the playground changes
    /// the whole catalogue, which is the same argument the other switches make.
    /// The ink on it is not a second setting: it follows from the tint.
    var tint = ShowcaseTint.amber

    /// The options as the library takes them.
    var options: TextMorphOptions {
        TextMorphOptions(
            duration: duration,
            ease: useSpring
                ? .spring(stiffness: stiffness, damping: damping)
                : .default,
            scale: scale,
            numbers: numbers,
            debug: debug,
            disabled: disabled
        )
    }

    /// The same, with a fraction length for a numeric value.
    func options(decimals: Int?, locale: Locale = defaultMorphLocale) -> TextMorphOptions {
        var options = options
        options.decimals = decimals
        options.locale = locale
        return options
    }

    /// The same, with the ease a particular demo asks for.
    ///
    /// Several of upstream's demos name their own ease rather than taking the
    /// default, and the choice is part of what the demo shows. Overriding
    /// through the settings rather than around them keeps the playground's
    /// switches working: debug, disabled and numbers still apply.
    ///
    /// The spring switch in the playground wins, so a reader can hear the whole
    /// catalogue on one spring if they want to.
    func options(
        ease: TextMorphEase, decimals: Int? = nil, duration: Double? = nil
    ) -> TextMorphOptions {
        var options = options
        if !useSpring { options.ease = ease }
        options.decimals = decimals
        if let duration { options.duration = duration }
        return options
    }

    /// The spring nine of upstream's demos ask for by name.
    ///
    /// Softer and slower than the default bezier, and it overshoots, which is
    /// why those demos are the ones where a value visibly settles rather than
    /// arriving.
    static let upstreamSpring = TextMorphEase.spring(
        stiffness: 150, damping: 19, mass: 1.2
    )

    /// The curve `ExampleAction` names.
    ///
    /// Its control points rise past one, so it overshoots and comes back.
    /// Upstream writes it as the CSS string `cubic-bezier(0.41, 1.03, 0.6,
    /// 1.03)`; the typed API takes the four numbers, which is the same curve.
    static let actionCurve = TextMorphEase.bezier(
        CubicBezier(0.41, 1.03, 0.6, 1.03)
    )
}
