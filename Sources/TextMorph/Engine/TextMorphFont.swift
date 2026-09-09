// Resolving a font this port can actually measure.
//
// SwiftUI's `Font` is opaque: it can be handed to a `Text` and nothing else. A
// morph has to shape the value itself, so it needs a real `CTFont`, and
// guessing one from the environment is not possible. So the font is described
// rather than passed, and the description yields both a `CTFont` to shape with
// and a SwiftUI `Font` for the accessibility node and for the plain `Text` this
// falls back to when nothing is moving.
//
// The default maps SwiftUI's text styles onto the platform's, which covers the
// overwhelmingly common case of `.font(.title)` and gets Dynamic Type for free.

import CoreText
import SwiftUI

#if canImport(UIKit)
    import UIKit

    /// The platform's own font type, which is what CoreText understands.
    typealias PlatformFont = UIFont
#else
    import AppKit

    typealias PlatformFont = NSFont
#endif

/// How a morph should be drawn.
public struct TextMorphFont: Hashable, Sendable {
    /// Which face and size.
    public enum Face: Hashable, Sendable {
        /// One of the platform's text styles, which scales with Dynamic Type.
        case textStyle(Font.TextStyle)
        /// The system face at a fixed size.
        case system(size: Double, weight: Font.Weight = .regular, design: Font.Design = .default)
        /// A named face at a fixed size.
        case custom(name: String, size: Double)
    }

    /// The face.
    public var face: Face

    /// Whether a fixed size scales with Dynamic Type.
    ///
    /// A text style always scales. A fixed size does not by default, which
    /// matches what `.font(.system(size:))` does, so a morph and a `Text` beside
    /// it behave the same way.
    public var scalesWithDynamicType: Bool

    /// Creates a font description.
    public init(face: Face, scalesWithDynamicType: Bool = false) {
        self.face = face
        self.scalesWithDynamicType = scalesWithDynamicType
    }

    /// The body text style, which is what a morph uses when nothing says
    /// otherwise.
    public static let body = TextMorphFont(face: .textStyle(.body))

    /// One of the platform's text styles.
    public static func textStyle(_ style: Font.TextStyle) -> TextMorphFont {
        TextMorphFont(face: .textStyle(style))
    }

    /// The system face at a fixed size.
    public static func system(
        size: Double, weight: Font.Weight = .regular, design: Font.Design = .default
    ) -> TextMorphFont {
        TextMorphFont(face: .system(size: size, weight: weight, design: design))
    }

    /// A named face at a fixed size.
    public static func custom(_ name: String, size: Double) -> TextMorphFont {
        TextMorphFont(face: .custom(name: name, size: size))
    }

    /// The SwiftUI font this describes, for the accessibility node and for the
    /// `Text` drawn when nothing is moving.
    public var swiftUIFont: Font {
        switch face {
        case let .textStyle(style):
            .system(style)
        case let .system(size, weight, design):
            .system(size: size, weight: weight, design: design)
        case let .custom(name, size):
            .custom(name, size: size)
        }
    }
}

// MARK: - resolving to something CoreText can shape

extension TextMorphFont {
    /// A resolved font, and whether resolving it had to settle for less.
    struct Resolved {
        let font: PlatformFont
        /// Set when the named face could not be found and the system face stood
        /// in. Debug mode says so, rather than the value quietly changing
        /// character.
        let substituted: Bool

        var ctFont: CTFont { font as CTFont }
    }

    /// Resolves the description against a size category.
    func resolve(dynamicTypeSize: DynamicTypeSize = .large) -> Resolved {
        switch face {
        case let .textStyle(style):
            return Resolved(font: Self.preferred(style, dynamicTypeSize), substituted: false)

        case let .system(size, weight, design):
            let base = Self.systemFont(size: size, weight: weight, design: design)
            return Resolved(font: scaled(base, dynamicTypeSize), substituted: false)

        case let .custom(name, size):
            guard let custom = PlatformFont(name: name, size: size) else {
                let fallback = Self.systemFont(size: size, weight: .regular, design: .default)
                return Resolved(font: scaled(fallback, dynamicTypeSize), substituted: true)
            }
            return Resolved(font: scaled(custom, dynamicTypeSize), substituted: false)
        }
    }

    private func scaled(_ font: PlatformFont, _ size: DynamicTypeSize) -> PlatformFont {
        guard scalesWithDynamicType else { return font }
        return Self.scale(font, to: size)
    }

    private static func systemFont(
        size: Double, weight: Font.Weight, design: Font.Design
    ) -> PlatformFont {
        let base = PlatformFont.systemFont(ofSize: size, weight: platformWeight(weight))
        guard design != .default else { return base }
        guard let descriptor = base.fontDescriptor.withDesign(platformDesign(design)) else {
            return base
        }
        #if canImport(UIKit)
            return PlatformFont(descriptor: descriptor, size: size)
        #else
            return PlatformFont(descriptor: descriptor, size: size) ?? base
        #endif
    }

    private static func platformDesign(
        _ design: Font.Design
    ) -> PlatformFontDescriptor.SystemDesign {
        switch design {
        case .serif: .serif
        case .rounded: .rounded
        case .monospaced: .monospaced
        default: .default
        }
    }

    private static func platformWeight(_ weight: Font.Weight) -> PlatformFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

// The platform's font descriptor type, whose name differs between the two.
#if canImport(UIKit)
    typealias PlatformFontDescriptor = UIFontDescriptor
#else
    typealias PlatformFontDescriptor = NSFontDescriptor
#endif
