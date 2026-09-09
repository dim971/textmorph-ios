// Everything a morph can be told, and the value it is told to show.

import Foundation

/// What a morph is showing.
///
/// A number is kept as a number rather than formatted by the caller, because
/// the formatting is part of the morph: the locale decides the decimal
/// separator, and the decimal separator is the pivot every digit alignment is
/// measured from.
public enum MorphValue: Hashable, Sendable {
    case text(String)
    case number(Double)
}

/// How a morph behaves.
///
/// Upstream's options, with the callbacks deliberately left out. Upstream keeps
/// them out of the key it compares to decide whether to tear the morph down and
/// start again, and for the same reason they are not part of this: a view that
/// passes a fresh closure on every update should not restart a morph in flight.
public struct TextMorphOptions: Hashable, Sendable {
    /// How long a morph takes, in milliseconds. Ignored when `ease` is a
    /// spring, which settles on its own physics.
    public var duration: Double

    /// What the morph moves like.
    public var ease: TextMorphEase

    /// Whether a leaving segment shrinks as it goes.
    public var scale: Bool

    /// Whether a numeric word morphs by place value. Off falls back to the
    /// character-level morph, which is what a version number or a code wants.
    public var numbers: Bool

    /// Fraction digits for a numeric value, setting both the minimum and the
    /// maximum. Ignored for a string.
    public var decimals: Int?

    /// The locale that decides the decimal separator, and how a numeric value
    /// is formatted.
    public var locale: Locale

    /// Draws the segment boxes and says what the shaper had to settle for.
    public var debug: Bool

    /// Turns the morphing off. The value still changes, it just arrives
    /// already in place.
    public var disabled: Bool

    /// Whether the system's reduce-motion setting turns the morphing off.
    public var respectReducedMotion: Bool

    /// Creates options, defaulting to upstream's.
    public init(
        duration: Double = 400,
        ease: TextMorphEase = .default,
        scale: Bool = true,
        numbers: Bool = true,
        decimals: Int? = nil,
        locale: Locale = defaultMorphLocale,
        debug: Bool = false,
        disabled: Bool = false,
        respectReducedMotion: Bool = true
    ) {
        self.duration = duration
        self.ease = ease
        self.scale = scale
        self.numbers = numbers
        self.decimals = decimals
        self.locale = locale
        self.debug = debug
        self.disabled = disabled
        self.respectReducedMotion = respectReducedMotion
    }

    /// Upstream's defaults.
    public static let `default` = TextMorphOptions()

    /// The string a value shows, under these options.
    func formatted(_ value: MorphValue) -> String {
        switch value {
        case let .text(text):
            text
        case let .number(number):
            NumberFormatting.format(number, decimals: decimals, locale: locale)
        }
    }
}

/// What to do when a morph ends.
///
/// Exactly one of these runs per morph, which is upstream's contract and is
/// enforced here by a single-shot token rather than by care.
public struct MorphCallbacks: Sendable {
    /// Fired when a morph begins, and never on the first value.
    public var onStart: (@Sendable @MainActor () -> Void)?
    /// Fired when a morph runs its course.
    public var onComplete: (@Sendable @MainActor () -> Void)?
    /// Fired when a morph is replaced before it finished.
    public var onCancel: (@Sendable @MainActor () -> Void)?

    /// Creates a set of callbacks.
    public init(
        onStart: (@Sendable @MainActor () -> Void)? = nil,
        onComplete: (@Sendable @MainActor () -> Void)? = nil,
        onCancel: (@Sendable @MainActor () -> Void)? = nil
    ) {
        self.onStart = onStart
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
}
