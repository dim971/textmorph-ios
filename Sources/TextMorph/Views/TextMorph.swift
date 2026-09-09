// The one public view, mirroring upstream's one public component.

import SwiftUI

/// Text that keeps its continuity when it changes.
///
/// When the value changes, the characters, words and digits that survive the
/// change move to their new place instead of disappearing in a cross-fade. A
/// number is a special case: its digits slide along the block axis by place
/// value, so 1,204 becoming 1,318 rolls the hundreds and the tens and leaves
/// the thousands alone.
///
/// ```swift
/// TextMorph(.number(total), options: TextMorphOptions(decimals: 2))
///     .textMorphFont(.textStyle(.largeTitle))
/// ```
///
/// The font is described rather than inherited, because SwiftUI's `Font` cannot
/// be measured: see ``TextMorphFont``. Without `.textMorphFont(_:)` a morph
/// draws at the body text style.
///
/// This is not a replacement for `Text`. It draws its own glyphs, so the value
/// cannot be selected, in any mode, and it is meant for values a reader watches
/// change: counters, prices, labels, statuses. Body copy wants `Text`.
///
/// A morph lines up with the text around it through its first baseline, so an
/// `HStack` with `.firstTextBaseline` alignment puts a morph and a `Text` on the
/// same line. Its box is not the same as a `Text`'s: SwiftUI gives a `Text` its
/// own line box by a rule of its own, and this uses the font's own metrics.
public struct TextMorph: View {
    private let value: MorphValue
    private let options: TextMorphOptions
    private let cursorIndex: Int?
    private let callbacks: MorphCallbacks

    @Environment(\.textMorphFont) private var font
    @Environment(\.textMorphColour) private var colour
    @Environment(\.self) private var environment: EnvironmentValues
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.multilineTextAlignment) private var textAlignment
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var host = MorphHost()

    /// Shows a string.
    public init(
        _ text: String,
        options: TextMorphOptions = .default,
        cursorIndex: Int? = nil,
        callbacks: MorphCallbacks = MorphCallbacks()
    ) {
        self.init(.text(text), options: options, cursorIndex: cursorIndex, callbacks: callbacks)
    }

    /// Shows a number, formatted by the options.
    public init(
        _ number: Double,
        options: TextMorphOptions = .default,
        cursorIndex: Int? = nil,
        callbacks: MorphCallbacks = MorphCallbacks()
    ) {
        self.init(.number(number), options: options, cursorIndex: cursorIndex, callbacks: callbacks)
    }

    /// Shows a value.
    public init(
        _ value: MorphValue,
        options: TextMorphOptions = .default,
        cursorIndex: Int? = nil,
        callbacks: MorphCallbacks = MorphCallbacks()
    ) {
        self.value = value
        self.options = options
        self.cursorIndex = cursorIndex
        self.callbacks = callbacks
    }

    /// The morph.
    public var body: some View {
        content
            // The plain value, in one piece. The glyphs the canvas draws carry
            // no semantics at all, which is the same arrangement upstream has:
            // aria-hidden spans beside one readable node.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(options.formatted(value)))
            .accessibilityAddTraits(.isStaticText)
            .onAppear { apply(); host.show(value, cursorIndex: cursorIndex, callbacks: callbacks) }
            .onChange(of: value) { host.show(value, cursorIndex: cursorIndex, callbacks: callbacks) }
            .onChange(of: options) { apply() }
            .onChange(of: font) { apply() }
            .onChange(of: dynamicTypeSize) { apply() }
            .onChange(of: reduceMotion) { apply() }
            .onChange(of: alignment) { apply() }
    }

    private var content: some View {
        // One rendering path, whether anything is moving or not.
        //
        // A plain `Text` would be the obvious fallback when the morphing is
        // off, and it would bring text selection with it. It is not used,
        // because it does not land in the same place: SwiftUI gives a `Text`
        // its own line box by a rule of its own, about a point shallower than
        // the font's own ascent plus descent plus leading at 26pt, so toggling
        // `disabled` or the reduce-motion setting would shift the value
        // vertically. Reproducing that rule would mean depending on a private
        // detail that is free to change with the OS.
        //
        // So the value is always drawn by the canvas, and what bridges it to
        // the text around it is the published first baseline rather than a
        // matching box. The cost is that a morph is never selectable, which is
        // documented, and which is a fair price for a counter.
        MorphTimeline(
            host: host,
            colour: colour.resolve(in: environment),
            debug: options.debug
        )
    }

    private var alignment: MorphAlignment {
        switch textAlignment {
        case .leading: layoutDirection == .rightToLeft ? .trailing : .leading
        case .center: .centre
        case .trailing: layoutDirection == .rightToLeft ? .leading : .trailing
        }
    }

    private func apply() {
        host.configure(
            font: font,
            dynamicTypeSize: dynamicTypeSize,
            options: options,
            alignment: alignment,
            reduceMotion: reduceMotion
        )
    }
}

// MARK: - the clock

/// Drives the canvas off a linear clock, and stops when nothing is moving.
///
/// `TimelineView(.animation)` hands over a date and nothing else, which is
/// exactly what is wanted: every curve is applied by the plan, and an eased
/// clock would make every opacity window wrong. It is paused when the morph has
/// settled, so a screen full of these costs nothing at rest.
private struct MorphTimeline: View {
    let host: MorphHost
    let colour: Color.Resolved
    let debug: Bool

    var body: some View {
        TimelineView(.animation(paused: !host.isRunning)) { timeline in
            let now = host.isRunning ? timeline.date : host.settledAt
            let size = host.engine?.size(at: now) ?? .zero
            // Read here rather than inside the guide's closure, which is
            // Sendable and so cannot reach main-actor state.
            let baseline = host.engine?.firstBaseline ?? 0

            // The layout size and the drawing surface are two different
            // things: the surface is allowed to overflow, the layout is not, or
            // a morph would shove its neighbours around as it goes. A clear
            // view of the layout size carries the frame, and the canvas rides
            // on top of it, larger, pulled back into place.
            Color.clear
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .topLeading) { canvas(at: now, size: size) }
                .alignmentGuide(.firstTextBaseline) { _ in CGFloat(baseline) }
        }
    }

    @ViewBuilder private func canvas(at now: Date, size: MorphSize) -> some View {
        if let engine = host.engine, let store = host.store, let render = engine.render(at: now) {
            let canvas = TextMorphCanvas(
                plan: render.plan,
                frame: render.frame,
                ghosts: render.ghosts,
                store: store,
                size: size,
                colour: colour,
                debug: debug
            )
            canvas.offset(x: -canvas.bleed, y: -canvas.bleed)
        } else {
            Color.clear
        }
    }
}

// MARK: - what the view owns

/// The engine and its store, kept across view updates.
///
/// Observable so the timeline restarts when a morph begins. Nothing here is
/// read from inside a draw pass except through the engine, which reads only the
/// clock.
@MainActor
@Observable
final class MorphHost {
    private(set) var store: LayoutStore?
    private(set) var engine: MorphEngine?

    /// Whether the timeline should be asking for frames.
    private(set) var isRunning = false
    /// The moment the last morph finished, so a paused timeline draws the
    /// settled frame rather than whatever date it happens to be handed.
    private(set) var settledAt = Date.distantFuture

    private var stopper: Task<Void, Never>?

    /// Points the engine at a font and a set of options.
    func configure(
        font: TextMorphFont,
        dynamicTypeSize: DynamicTypeSize,
        options: TextMorphOptions,
        alignment: MorphAlignment,
        reduceMotion: Bool
    ) {
        let store = store ?? LayoutStore(font: font, dynamicTypeSize: dynamicTypeSize)
        store.use(font: font, dynamicTypeSize: dynamicTypeSize)
        self.store = store

        guard let engine else {
            engine = MorphEngine(
                store: store, options: options,
                alignment: alignment, reduceMotion: reduceMotion
            )
            return
        }
        engine.configure(options: options, alignment: alignment, reduceMotion: reduceMotion)
    }

    /// Shows a value, and runs the clock for as long as it takes.
    func show(_ value: MorphValue, cursorIndex: Int?, callbacks: MorphCallbacks) {
        guard let engine else { return }
        let now = Date()
        guard engine.update(value, cursorIndex: cursorIndex, callbacks: callbacks, now: now) else {
            return
        }

        guard let render = engine.render(at: now), !render.isSettled else {
            stop(at: now)
            return
        }

        isRunning = true
        settledAt = .distantFuture
        stopper?.cancel()
        // A generous tail: a ghost from an interrupted morph can outlast the
        // one that replaced it, and the cost of a few extra frames is nothing
        // next to a morph that stops half way.
        let tail = render.plan.durationMs / 1000 + 0.1
        stopper = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(tail))
            guard !Task.isCancelled else { return }
            self?.stop(at: Date())
        }
    }

    private func stop(at now: Date) {
        settledAt = now
        isRunning = false
    }
}

public extension EnvironmentValues {
    /// The font a morph draws with.
    @Entry var textMorphFont: TextMorphFont = .body

    /// The colour a morph draws with.
    @Entry var textMorphColour: Color = .primary
}

public extension View {
    /// Sets the font a morph draws with.
    ///
    /// A morph shapes its own text, so it needs a font it can measure, and
    /// SwiftUI's `Font` is not one: it can be handed to a `Text` and to nothing
    /// else. This is the way to say what a morph should look like, and
    /// `.font(_:)` has no effect on one.
    func textMorphFont(_ font: TextMorphFont) -> some View {
        environment(\.textMorphFont, font)
    }

    /// Sets the colour a morph draws with.
    ///
    /// Needed for the same reason as `textMorphFont(_:)`, and it is the same
    /// limitation: a morph fills its own glyphs, and `.foregroundStyle(_:)` is
    /// not something a view can read back out of the environment, so it has no
    /// effect on one. The default is `.primary`, which is what a `Text` uses.
    func textMorphColour(_ colour: Color) -> some View {
        environment(\.textMorphColour, colour)
    }
}
