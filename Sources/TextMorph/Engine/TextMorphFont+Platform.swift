// The two places resolving a font is not the same on both platforms: reading a
// text style, and scaling a fixed size with Dynamic Type.

import SwiftUI

#if canImport(UIKit)
    import UIKit

    extension TextMorphFont {
        static func preferred(_ style: Font.TextStyle, _ size: DynamicTypeSize) -> PlatformFont {
            UIFont.preferredFont(
                forTextStyle: platformStyle(style),
                compatibleWith: UITraitCollection(preferredContentSizeCategory: category(size))
            )
        }

        static func scale(_ font: PlatformFont, to size: DynamicTypeSize) -> PlatformFont {
            // Scaled against the body style, which is what
            // `.font(.system(size:))` does when Dynamic Type is asked for.
            UIFontMetrics(forTextStyle: .body).scaledFont(
                for: font,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: category(size))
            )
        }

        /// A lookup table rather than a switch, because that is what it is.
        ///
        /// A style this SDK does not know about, which is how the newer
        /// extra-large titles arrive, falls back to body: too small rather than
        /// wrong in an unpredictable direction.
        private static let styles: [Font.TextStyle: UIFont.TextStyle] = [
            .largeTitle: .largeTitle,
            .title: .title1,
            .title2: .title2,
            .title3: .title3,
            .headline: .headline,
            .subheadline: .subheadline,
            .body: .body,
            .callout: .callout,
            .footnote: .footnote,
            .caption: .caption1,
            .caption2: .caption2
        ]

        private static let categories: [DynamicTypeSize: UIContentSizeCategory] = [
            .xSmall: .extraSmall,
            .small: .small,
            .medium: .medium,
            .large: .large,
            .xLarge: .extraLarge,
            .xxLarge: .extraExtraLarge,
            .xxxLarge: .extraExtraExtraLarge,
            .accessibility1: .accessibilityMedium,
            .accessibility2: .accessibilityLarge,
            .accessibility3: .accessibilityExtraLarge,
            .accessibility4: .accessibilityExtraExtraLarge,
            .accessibility5: .accessibilityExtraExtraExtraLarge
        ]

        private static func platformStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
            styles[style] ?? .body
        }

        private static func category(_ size: DynamicTypeSize) -> UIContentSizeCategory {
            categories[size] ?? .large
        }
    }

#else
    import AppKit

    extension TextMorphFont {
        static func preferred(_ style: Font.TextStyle, _: DynamicTypeSize) -> PlatformFont {
            NSFont.preferredFont(forTextStyle: platformStyle(style))
        }

        /// macOS has no Dynamic Type, so a fixed size is a fixed size. The
        /// parameter is kept so the two platforms share one call site.
        static func scale(_ font: PlatformFont, to _: DynamicTypeSize) -> PlatformFont {
            font
        }

        /// A lookup table rather than a switch, matching the UIKit side, and
        /// falling back to body for a style this SDK does not know about.
        private static let styles: [Font.TextStyle: NSFont.TextStyle] = [
            .largeTitle: .largeTitle,
            .title: .title1,
            .title2: .title2,
            .title3: .title3,
            .headline: .headline,
            .subheadline: .subheadline,
            .body: .body,
            .callout: .callout,
            .footnote: .footnote,
            .caption: .caption1,
            .caption2: .caption2
        ]

        private static func platformStyle(_ style: Font.TextStyle) -> NSFont.TextStyle {
            styles[style] ?? .body
        }
    }
#endif
