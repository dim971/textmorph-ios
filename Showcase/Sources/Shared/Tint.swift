import SwiftUI

// The colours the tinted cards can be drawn in, and how to write on them.
//
// Upstream's own, read out of its stylesheet and its rating scale rather than
// picked to look similar: `--primary: #ffce44` is the accent the whole site runs
// on, and the other five are the tones its rating slider walks through. A
// palette that merely rhymes with a reference is a palette that drifts from it;
// these are the same numbers. The Kotlin twin carries the same file.

/// One choice of tint, with a name a reader can say.
enum ShowcaseTint: String, CaseIterable, Identifiable {
    /// Upstream's `--primary`, and the default here for the same reason.
    case amber
    case yellow
    case orange
    case red
    case green
    case blue

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var colour: Color {
        switch self {
        case .amber: Color(red: 1, green: 0.808, blue: 0.267)
        case .yellow: Color(red: 0.941, green: 0.706, blue: 0.161)
        case .orange: Color(red: 1, green: 0.478, blue: 0.184)
        case .red: Color(red: 0.949, green: 0.271, blue: 0.239)
        case .green: Color(red: 0.204, green: 0.780, blue: 0.349)
        case .blue: Color(red: 0.231, green: 0.510, blue: 0.965)
        }
    }

    /// Black or white, whichever this tint can be read through.
    var ink: Color { onTint(colour) }
}

/// The luminance at which black and white are equally readable.
private let contrastPivot = 0.179

/// Black or white on a given colour, whichever reads better.
///
/// WCAG relative luminance, and the threshold is where the contrast against
/// black and the contrast against white are equal rather than a number chosen
/// by eye. It matters here because the palette runs from an amber that wants
/// black to a dark accent that wants white, and a hardcoded ink is only ever
/// right for one of them: this replaces a black that was hardcoded on six
/// cards.
func onTint(_ background: Color) -> Color {
    luminance(background) > contrastPivot ? .black : .white
}

private func luminance(_ colour: Color) -> Double {
    let parts = UIColor(colour).cgColor.components ?? [0, 0, 0]
    guard parts.count >= 3 else {
        // A greyscale colour reports one component plus its alpha.
        return linear(Double(parts.first ?? 0))
    }
    return 0.2126 * linear(Double(parts[0]))
        + 0.7152 * linear(Double(parts[1]))
        + 0.0722 * linear(Double(parts[2]))
}

/// One sRGB channel, undone back to light.
private func linear(_ channel: Double) -> Double {
    channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
}
