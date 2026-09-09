import SwiftUI

// A track with a bubble hanging off its thumb.
//
// Three of upstream's cards are this shape, and on two of them the motion is
// the demo rather than the decoration: the bubble trails its thumb and leans
// into the travel, and where two bubbles meet they pivot apart about their tail
// tips. Both come from `Bubbles.swift`, transcribed from upstream with its own
// constants.
//
// One difference from the Kotlin twin worth naming: there the loop is driven by
// `withFrameNanos`, which is vsync; here it is a sixteen millisecond sleep.
// Close enough for a pill, and the physics is stepped once per tick either way,
// so the two settle in the same number of steps.

private let thumbSize = 18.0
private let trackHeight = 4.0

/// Where the track sits under the bubbles.
private let trackTop = 62.0

/// Where a tail tip sits: the top of the thumb rather than its centre.
///
/// On the centre the thumb covers the tail entirely and the pill reads as a
/// plain pill with a notch bitten out of it. Three points of overlap is enough
/// to look attached without being swallowed.
private let pillBottom = trackTop + trackHeight / 2 - thumbSize / 2 + 3

/// The state one tick of the physics writes, and the layout reads. All in points.
@Observable
final class TrackMotion {
    var lag: [Double]
    var tilt: [Double]
    var stretch: [Double]
    var width: [Double]
    var height: [Double]

    /// How pressed together the pair are, kept unclamped because that is where
    /// the spring's overshoot lives. Clamped only where it is read.
    var shove = 0.0
    var squash = 0.0
    var lean = 0.0

    private let bobs: [Bob]
    private var shoveVelocity = 0.0
    private var started = false

    init(count: Int) {
        lag = Array(repeating: 0, count: count)
        tilt = Array(repeating: 0, count: count)
        stretch = Array(repeating: 0, count: count)
        width = Array(repeating: 0, count: count)
        height = Array(repeating: 0, count: count)
        bobs = (0 ..< count).map { _ in Bob() }
    }

    /// Points the thumbs at new values. The first aim carries rather than swings.
    func aim(at targets: [Double]) {
        for (index, target) in targets.enumerated() where index < bobs.count {
            if !started { bobs[index].carry(to: target) }
            bobs[index].x = target
        }
        started = true
        publish()
    }

    /// One tick. Returns whether anything is still moving.
    func step() -> Bool {
        for bob in bobs {
            bob.swing()
        }

        var target = 0.0
        if bobs.count > 1 {
            target = shoveTarget(
                loWidth: width[0], hiWidth: width[1], gap: bobs[1].x - bobs[0].x
            )
        }
        shoveVelocity = (shoveVelocity + (target - shove) * shoveStiffness) * shoveDamping
        shove += shoveVelocity
        squash = min(max(shove, 0), 1) * shoveSquash

        publish()

        let bobsSettled = bobs.allSatisfy(\.isSettled)
        let shoveSettled = abs(shoveVelocity) < 0.001 && abs(target - shove) < 0.002
        return !(bobsSettled && shoveSettled)
    }

    private func publish() {
        for (index, bob) in bobs.enumerated() {
            lag[index] = bob.lag
            tilt[index] = bob.tilt
            stretch[index] = bob.stretch
        }
        lean = bobs.count > 1
            ? leanApart(
                loBox: body(0),
                hiBox: body(1),
                loTilt: tilt[0],
                hiTilt: tilt[1],
                loX: bobs[0].lag,
                hiX: bobs[1].lag
            )
            : 0
    }

    private func body(_ index: Int) -> BubbleBox {
        BubbleBox(
            width: width[index],
            height: max(height[index], 1),
            scaleX: scaleXOf(stretch: stretch[index], squash: squash),
            scaleY: 1 + stretch[index]
        )
    }
}

/// One bubble on one thumb.
struct BubbleTrack<Bubble: View>: View {
    let fraction: Double
    var trackWidth = 240.0
    var bubbleColour: Color?
    var onFraction: ((Double) -> Void)?
    @ViewBuilder let bubble: () -> Bubble

    var body: some View {
        var handler: ((Int, Double) -> Void)?
        if let onFraction {
            handler = { _, value in onFraction(value) }
        }
        return RangeTrack(
            fractions: [fraction],
            trackWidth: trackWidth,
            bubbleColour: bubbleColour,
            onFraction: handler,
            bubbles: [AnyView(bubble())]
        )
    }
}

/// A track carrying one or two bubbles.
///
/// Two is the interesting case: both tails stay pinned to their thumbs, so
/// leaning is the only way out of an overlap, and how far they lean is found by
/// bisecting on the daylight between their bodies. That is upstream's rule, and
/// it is the whole of the Range shove card.
struct RangeTrack: View {
    let fractions: [Double]
    var trackWidth = 240.0
    /// Nil takes the theme's own accent, which is what most of these want.
    var bubbleColour: Color?
    var onFraction: ((Int, Double) -> Void)?
    let bubbles: [AnyView]

    @State private var motion: TrackMotion

    /// Which thumb the drag in progress belongs to.
    @State private var held: Int?

    init(
        fractions: [Double],
        trackWidth: Double = 240.0,
        bubbleColour: Color? = nil,
        onFraction: ((Int, Double) -> Void)? = nil,
        bubbles: [AnyView]
    ) {
        self.fractions = fractions
        self.trackWidth = trackWidth
        self.bubbleColour = bubbleColour
        self.onFraction = onFraction
        self.bubbles = bubbles
        _motion = State(initialValue: TrackMotion(count: fractions.count))
    }

    private var span: Double { trackWidth - thumbSize }

    private func thumbAt(_ fraction: Double) -> Double {
        thumbSize / 2 + span * min(max(fraction, 0), 1)
    }

    private var targets: [Double] { fractions.map(thumbAt) }

    private var from: Double { fractions.count > 1 ? fractions[0] : 0 }

    /// The targets as one value, so the loop restarts when they move and not
    /// when the array happens to be a new object.
    private var targetsKey: String {
        targets.map { String(format: "%.3f", $0) }.joined(separator: ",")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            rail
            fill
            ForEach(fractions.indices, id: \.self) { index in
                thumb(index)
            }
            // The pills live in their own layer, tall enough to reach the
            // track's centre line and bottom-aligned, so every tail tip lands
            // on its thumb.
            ZStack(alignment: .bottom) {
                ForEach(fractions.indices, id: \.self) { index in
                    pill(index)
                }
            }
            .frame(width: trackWidth, height: pillBottom, alignment: .bottom)

            // One gesture over the whole width, and on top of everything,
            // because upstream's slider is a native range input spanning the
            // track: a reader can grab it anywhere, not only on the thumb, and
            // that is most of why the site feels continuous. On top rather than
            // underneath because a filled shape hit-tests, so a rail and two
            // pills drawn over the gesture would swallow most of it.
            //
            // The position is read absolutely from the touch rather than
            // accumulated from the incoming value, which is the bug this
            // replaces: adding a cumulative translation to a value the same
            // gesture had already moved counted every point twice over.
            Color.clear
                .contentShape(.rect)
                .frame(width: trackWidth, height: trackTop + thumbSize)
                .gesture(slide, including: onFraction == nil ? .none : .all)
        }
        .frame(width: trackWidth, height: trackTop + thumbSize, alignment: .topLeading)
        .task(id: targetsKey) {
            motion.aim(at: targets)
            // Runs until the springs settle and then stops, so a track at rest
            // costs nothing.
            while !Task.isCancelled, motion.step() {
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private var rail: some View {
        Capsule()
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(width: trackWidth, height: trackHeight)
            .offset(y: trackTop)
    }

    private var fill: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(
                width: span * min(max(fractions.last! - from, 0), 1),
                height: trackHeight
            )
            .offset(x: thumbSize / 2 + span * min(max(from, 0), 1), y: trackTop)
    }

    private func thumb(_ index: Int) -> some View {
        let centre = thumbAt(fractions[index])
        return Circle()
            // Pale rather than ink, which is upstream's: a dark disc under a
            // coloured pill reads as a hole, and it swallows the tail.
            .fill(Color(uiColor: .systemBackground))
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
            .shadow(radius: 1, y: 1)
            .frame(width: thumbSize, height: thumbSize)
            .offset(x: centre - thumbSize / 2, y: trackTop - thumbSize / 2 + trackHeight / 2)
            .allowsHitTesting(false)
    }

    /// The pill rides the bob rather than the thumb, and pivots about its own
    /// tail tip. Bottom-aligned in a box reaching the track's centre line, so
    /// the tip lands on the thumb whatever the pill's own height turns out to
    /// be, and centred horizontally by a full-width frame because half its width
    /// is unknown until it is measured.
    private func pill(_ index: Int) -> some View {
        let apart: Double = fractions.count < 2 ? 0 : (index == 0 ? -motion.lean : motion.lean)
        let stretch = motion.stretch[index]

        return bubbles[index]
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 4 + bubbleTail)
            .background(bubbleColour ?? Color.accentColor, in: BubbleShape())
            .background {
                GeometryReader { geometry in
                    Color.clear.task(id: geometry.size) {
                        motion.width[index] = geometry.size.width
                        motion.height[index] = geometry.size.height - bubbleTail
                    }
                }
            }
            .scaleEffect(
                x: scaleXOf(stretch: stretch, squash: motion.squash),
                y: 1 + stretch,
                anchor: .bottom
            )
            .rotationEffect(.degrees(motion.tilt[index] + apart), anchor: .bottom)
            .frame(width: trackWidth, alignment: .center)
            .offset(x: motion.lag[index] - trackWidth / 2)
    }

    private var slide: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let onFraction else { return }
                let touched = fractionOf(value.location.x)
                // The nearer thumb, which is what a reader means by grabbing
                // near it, and the only sensible answer once a range's two
                // thumbs are close enough to be leaning apart. Chosen once, at
                // the start, so a drag cannot hand over mid-gesture.
                if held == nil { held = nearest(to: touched) }
                onFraction(held ?? 0, touched)
            }
            .onEnded { _ in held = nil }
    }

    /// Where a touch falls along the track, as a fraction.
    ///
    /// Bounded here rather than by the caller, because a fraction is the
    /// track's own contract: a demo that has to remember to clamp is a demo
    /// that will one day show 105%.
    private func fractionOf(_ x: Double) -> Double {
        guard span > 0 else { return 0 }
        return min(max((x - thumbSize / 2) / span, 0), 1)
    }

    private func nearest(to fraction: Double) -> Int {
        var best = 0
        var distance = Double.greatestFiniteMagnitude
        for (index, value) in fractions.enumerated() where abs(value - fraction) < distance {
            distance = abs(value - fraction)
            best = index
        }
        return best
    }
}

/// A rounded body with a tail hanging off the bottom, tip down.
///
/// The tip is where the bubble pivots, which is why it is part of the shape
/// rather than a separate view: the rotation's anchor can then be the bottom of
/// the box and mean the right thing.
private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let body = rect.height - bubbleTail
        var path = Path(
            roundedRect: CGRect(x: 0, y: 0, width: rect.width, height: body),
            cornerRadius: bubbleRadius
        )
        // Symmetric, and its apex is exactly the bottom centre of the box,
        // which is what the rotation anchors on. An off-centre apex means the
        // pill pivots about a point that is not its tip, so the tail slides off
        // the thumb as it leans.
        path.move(to: CGPoint(x: rect.width / 2 - bubbleTailHalfBase, y: body - 1))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width / 2 + bubbleTailHalfBase, y: body - 1))
        path.closeSubpath()
        return path
    }
}
