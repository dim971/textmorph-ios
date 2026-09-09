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
}
