import SwiftUI

// A track with a bubble riding its thumb.
//
// Three of upstream's demos are this shape. Upstream hangs the bubble on a
// spring so it leans into the travel, and where two bubbles meet it solves a
// separating-axis test and leans them apart. None of that is reproduced here:
// the bubble is carried rather than thrown. What is kept is the thing the demo
// exists for, which is a value morphing inside a box that is moving.

private let thumbSize = 18.0
private let trackHeight = 4.0

/// Where the track sits under the bubbles.
private let trackTop = 72.0

/// Where a pill sits, and where it goes when it has to make room.
private let pillTop = 34.0
private let pillLifted = 0.0

/// A track carrying one or two bubbles.
///
/// Two is the interesting case, and it is where this parts company with
/// upstream: when the bubbles would overlap, upstream leans them apart about
/// their tails, and this lifts the lower one clear instead. Simpler, and it
/// keeps both values readable, which is what the leaning is for.
struct RangeTrack: View {
    let fractions: [Double]
    var trackWidth = 240.0
    /// Null takes the theme's own accent, which is what most of these want.
    var bubbleColour: Color?
    var onFraction: ((Int, Double) -> Void)?
    let bubbles: [AnyView]

    private var span: Double { trackWidth - thumbSize }

    /// Close enough that two pills would touch, in the units the track is in.
    /// Generous, because the pills are as wide as their values and a value can
    /// gain a digit mid-morph.
    private var crowded: Bool {
        fractions.count > 1 && (fractions[1] - fractions[0]) * span < 104
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: trackWidth, height: trackHeight)
                .offset(y: trackTop)

            Capsule()
                .fill(Color.accentColor)
                .frame(
                    width: span * max(0, min(1, fractions.last! - from)),
                    height: trackHeight
                )
                .offset(x: thumbSize / 2 + span * from, y: trackTop)

            ForEach(Array(fractions.enumerated()), id: \.offset) { index, fraction in
                let centre = thumbSize / 2 + span * max(0, min(1, fraction))

                Circle()
                    .fill(Color.primary)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: centre - thumbSize / 2, y: trackTop - thumbSize / 2 + trackHeight / 2)
                    .gesture(drag(index: index), including: onFraction == nil ? .none : .all)

                bubbles[index]
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(bubbleColour ?? Color.accentColor, in: .rect(cornerRadius: 12))
                    // Half the pill's own width is unknown until it is laid
                    // out, so it is centred on the thumb by an alignment guide
                    // rather than by arithmetic.
                    .alignmentGuide(.leading) { $0.width / 2 - centre }
                    .offset(y: crowded && index == 0 ? pillLifted : pillTop)
            }
        }
        .frame(width: trackWidth, height: trackTop + thumbSize, alignment: .topLeading)
    }

    private var from: Double {
        fractions.count > 1 ? fractions[0] : 0
    }

    private func drag(index: Int) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let onFraction else { return }
                let centre = thumbSize / 2 + span * max(0, min(1, fractions[index]))
                let x = centre + value.translation.width - thumbSize / 2
                onFraction(index, max(0, min(1, x / span)))
            }
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
        RangeTrack(
            fractions: [fraction],
            trackWidth: trackWidth,
            bubbleColour: bubbleColour,
            onFraction: onFraction.map { set in { _, value in set(value) } },
            bubbles: [AnyView(bubble())]
        )
    }
}
