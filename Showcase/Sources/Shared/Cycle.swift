import SwiftUI

/// Steps through a list of values, on a tap or on a timer.
///
/// Every demo needs the same thing: something that changes. Sharing it keeps
/// each demo about the one capability it is there to show.
@Observable
final class Cycle<Value> {
    private let values: [Value]
    private(set) var index = 0

    init(_ values: [Value]) {
        self.values = values
    }

    var current: Value { values[index] }

    func advance() {
        index = (index + 1) % values.count
    }
}

/// Whether a demo drives itself instead of waiting to be tapped.
///
/// Set in the catalogue, where a row's tap belongs to the navigation link and a
/// demo that only moves when tapped would be a screenshot.
extension EnvironmentValues {
    @Entry var showcaseAutoAdvance = false
}

/// A demo that advances when it is tapped, or on its own in the catalogue.
struct Tappable<Content: View>: View {
    let hint: String
    @ViewBuilder let content: () -> Content
    let advance: () -> Void

    @Environment(\.showcaseAutoAdvance) private var autoAdvance

    var body: some View {
        if autoAdvance {
            Ticking(interval: 1.6, content: content, advance: advance)
                .allowsHitTesting(false)
        } else {
            VStack(spacing: 12) {
                content()
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .onTapGesture(perform: advance)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(hint)
        }
    }
}

/// A demo that advances on its own.
struct Ticking<Content: View>: View {
    let interval: Double
    @ViewBuilder let content: () -> Content
    let advance: () -> Void

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled else { return }
                    advance()
                }
            }
    }
}
