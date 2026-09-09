import SwiftUI
import TextMorph

// The furniture the demos share.
//
// Every one of them is a value that changes inside a little piece of interface,
// so the interface is here and each demo is left saying only what changes and
// when. A demo that has to spell out its own padding is a demo whose point is
// buried.

/// The size most demos show a value at.
func stageFont(
    size: Double = 26,
    weight: Font.Weight = .medium,
    design: Font.Design = .default
) -> TextMorphFont {
    .system(size: size, weight: weight, design: design)
}

/// A centred value with an optional caption under it.
struct Stage<Content: View>: View {
    var caption: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 6) {
            content()
            if let caption {
                Caption(caption)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The small grey line under a value.
struct Caption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// A pill whose width follows its text.
///
/// The container animates its own size, so the pill grows and shrinks with the
/// value rather than jumping. That is the whole reason several of these demos
/// are pills.
struct Chip<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
    }
}

/// Two values side by side, which is how upstream shows a contrast.
struct SplitRow<Left: View, Right: View>: View {
    var separator: String?
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    var body: some View {
        HStack(spacing: 0) {
            left()
            if let separator {
                Text(separator)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                Spacer().frame(width: 28)
            }
            right()
        }
    }
}

// MARK: - clocks

/// Walks a list on a timer, which is what most of these demos are.
///
/// The interval is the demo's rather than the surface's: a demo in a catalogue
/// row and the same demo on its own screen should tick at the same rate,
/// because the rate is part of what the demo shows. Reduce motion stops the
/// cycle entirely, which is upstream's behaviour and the right one: a value
/// that jumps between four states on a timer is still motion, even when each
/// jump is instant.
struct Cycling<Content: View>: View {
    let count: Int
    let interval: Double
    @ViewBuilder let content: (Int) -> Content

    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content(index)
            .task(id: reduceMotion) {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled else { return }
                    index = (index + 1) % count
                }
            }
    }
}

/// Steps a value on a timer until someone touches the demo, then hands over.
///
/// Upstream's phrase for it, and the behaviour is worth copying: a demo that
/// keeps animating under a finger fights the finger, and a demo that never
/// moves is a screenshot.
@Observable
final class Autoplay {
    private(set) var isPlaying = true

    /// Called on the first touch.
    func takeOver() {
        isPlaying = false
    }
}

/// Runs a block on a timer for as long as the autoplay has not been taken over.
struct Autoplaying: ViewModifier {
    let autoplay: Autoplay
    let interval: Double
    let step: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled, autoplay.isPlaying {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, autoplay.isPlaying else { return }
                step()
            }
        }
    }
}

extension View {
    /// Drives a demo until it is touched.
    func autoplaying(
        _ autoplay: Autoplay, every interval: Double, step: @escaping () -> Void
    ) -> some View {
        modifier(Autoplaying(autoplay: autoplay, interval: interval, step: step))
    }
}

// MARK: - line breaking

/// Breaks a passage into lines of at most `maxChars`, greedily.
///
/// The library never wraps: a line exists only where the value put one, which
/// is upstream's design and the reason a value can be diffed at all. So a demo
/// that wants prose on several lines has to say where the breaks go, and this
/// is upstream's own helper, transcribed.
func wrap(_ text: String, _ maxChars: Int) -> String {
    var lines: [String] = []
    var line = ""
    for word in text.split(separator: " ", omittingEmptySubsequences: false) {
        let next = line.isEmpty ? String(word) : "\(line) \(word)"
        if !line.isEmpty, next.count > maxChars {
            lines.append(line)
            line = String(word)
        } else {
            line = next
        }
    }
    if !line.isEmpty { lines.append(line) }
    return lines.joined(separator: "\n")
}

// MARK: - grouping

/// A count with thousands separators, without going through a formatter.
///
/// The demos that show one want the same string on both platforms, and a
/// formatter would take it from the device's locale instead.
func grouped(_ value: Int) -> String {
    let digits = String(abs(value))
    var out: [String] = []
    var index = digits.endIndex
    while index > digits.startIndex {
        let start = digits.index(index, offsetBy: -3, limitedBy: digits.startIndex)
            ?? digits.startIndex
        out.insert(String(digits[start ..< index]), at: 0)
        index = start
    }
    let body = out.joined(separator: ",")
    return value < 0 ? "\u{2212}\(body)" : body
}

public extension EnvironmentValues {
    /// Whether a demo should accept a gesture.
    ///
    /// False in a catalogue row, and it has to be: a row is inside a scrolling
    /// list, and a demo that grabs a drag there eats the scroll. So the
    /// previews run themselves and answer to nothing, and a demo is only
    /// draggable on its own screen.
    @Entry var showcaseInteractive = true
}
