import CoreGraphics
import Foundation

// The physics two of upstream's cards are actually about.
//
// A bubble hangs off its thumb on a spring, so it trails the travel and leans
// into it, and where two bubbles meet they pivot apart about their tail tips
// rather than overlapping. Both are transcribed from torph's own
// site/src/surfaces/demos/slider.tsx, constants included, because on those two
// cards the motion is the demo: a pill that merely slides says nothing that a
// label would not.
//
// Everything here is in points, which is what a CSS pixel is, so upstream's
// numbers mean what they say. The Kotlin twin carries the same file.

/// How hard the bubble is pulled back over its thumb, and how fast it gives up.
private let stiffness = 0.16
private let damping = 0.67

/// Degrees of lean at full trail.
private let maxTilt = 28.0

/// Points of trail at one radian of tanh. Past it the lean saturates.
private let soft = 30.0

/// How much a fast bubble stretches along its travel, at most.
private let maxStretch = 0.13

/// A bubble on a spring, pinned to a thumb.
///
/// How far it trails is how far it leans, which is the whole trick: the lean is
/// not animated, it is read off the distance between where the bubble is and
/// where it should be.
final class Bob {
    /// Where the thumb is, in points along the track.
    var x = 0.0

    /// Where the bubble has got to.
    var lag = 0.0

    private var velocity = 0.0

    /// Snaps the bubble onto its thumb, for a reflow rather than a drag.
    func carry(to target: Double) {
        x = target
        lag = target
        velocity = 0
    }

    /// One frame of the spring.
    func swing() {
        velocity = (velocity + (x - lag) * stiffness) * damping
        lag += velocity
    }

    var isSettled: Bool {
        abs(velocity) < 0.02 && abs(x - lag) < 0.05
    }

    /// Degrees, positive leaning back the way it came.
    var tilt: Double { maxTilt * tanh((lag - x) / soft) }

    /// How much it is drawn out along its travel.
    var stretch: Double { min(abs(velocity) * 0.006, maxStretch) }
}

/// Horizontal scale, which shrinks as the bubble stretches and as it is squashed.
func scaleXOf(stretch: Double, squash: Double) -> Double {
    (1 - stretch * 0.7) * (1 - squash)
}

// MARK: - two bubbles in each other's way

/// Points of closeness at which the pair start to squash.
private let shovePad = 10.0

/// Points of daylight they hold once they meet.
private let shoveClear = 2.0

/// Degrees, however far it takes, up to lying flat on the tail.
let shoveLean = 90.0

let shoveStiffness = 0.2
let shoveDamping = 0.62

/// How much the pair squash into each other at full shove.
let shoveSquash = 0.16

/// Points the tail hangs below the body. Its tip is the pivot.
let bubbleTail = 9.0

/// Half the tail's base, so it reads as a tail rather than as a spike.
let bubbleTailHalfBase = 8.0

/// Points of corner rounding on the body.
let bubbleRadius = 14.0

/// A bubble's body, measured from its tail tip.
struct BubbleBox {
    let half: Double
    let top: Double
    let bottom: Double

    init(width: Double, height: Double, scaleX: Double, scaleY: Double) {
        half = (width / 2) * scaleX
        top = -(bubbleTail + height) * scaleY
        bottom = -bubbleTail * scaleY
    }
}

/// How pressed together a pair are, 0 to 1.
///
/// What the lean and the squash both ride on. Zero once there is room for both
/// bodies plus a pad; one when the thumbs are on top of each other.
func shoveTarget(loWidth: Double, hiWidth: Double, gap: Double) -> Double {
    let need = (loWidth + hiWidth) / 2 + shovePad
    guard need > 0 else { return 0 }
    return max(0, need - gap) / need
}

/// The body's box inset by its corner radius, swung about the tail tip at `x`.
///
/// A rounded rectangle is that box swept by a disc, so two of them meet arc to
/// arc once the boxes are two radii apart. That is what lets the whole test be
/// done on plain rectangles.
private func corners(of box: BubbleBox, tilt: Double, x: Double) -> [CGPoint] {
    let radians = tilt * .pi / 180
    let s = sin(radians)
    let c = cos(radians)
    let half = max(box.half - bubbleRadius, 0)
    func at(_ px: Double, _ py: Double) -> CGPoint {
        CGPoint(x: x + px * c - py * s, y: px * s + py * c)
    }
    return [
        at(-half, box.top + bubbleRadius),
        at(half, box.top + bubbleRadius),
        at(half, box.bottom - bubbleRadius),
        at(-half, box.bottom - bubbleRadius)
    ]
}

private func span(of poly: [CGPoint], nx: Double, ny: Double) -> (low: Double, high: Double) {
    var low = Double.greatestFiniteMagnitude
    var high = -Double.greatestFiniteMagnitude
    for p in poly {
        let d = p.x * nx + p.y * ny
        low = min(low, d)
        high = max(high, d)
    }
    return (low, high)
}

private func overlaps(_ a: [CGPoint], _ b: [CGPoint]) -> Bool {
    for poly in [a, b] {
        for i in 0 ..< 2 {
            let p = poly[i]
            let q = poly[i + 1]
            let length = hypot(q.x - p.x, q.y - p.y)
            let unit = length == 0 ? 1 : length
            let nx = (q.y - p.y) / unit
            let ny = (p.x - q.x) / unit
            let spanA = span(of: a, nx: nx, ny: ny)
            let spanB = span(of: b, nx: nx, ny: ny)
            if spanB.low > spanA.high || spanA.low > spanB.high { return false }
        }
    }
    return true
}

private func edgeDistance(_ v: CGPoint, _ p: CGPoint, _ q: CGPoint) -> Double {
    let ex = q.x - p.x
    let ey = q.y - p.y
    let along = ex * ex + ey * ey
    let t = along == 0 ? 0 : min(max(((v.x - p.x) * ex + (v.y - p.y) * ey) / along, 0), 1)
    return hypot(v.x - p.x - t * ex, v.y - p.y - t * ey)
}

/// Daylight between two leaning bodies, negative once they cross.
///
/// Their closest approach, not their horizontal extents: bodies tilted into a V
/// meet on their near corners, which the extents pass long before the corners
/// are anywhere near each other. Upstream's note, and its reason for doing this
/// the expensive way.
private func gap(between a: [CGPoint], and b: [CGPoint]) -> Double {
    var near = Double.greatestFiniteMagnitude
    for (poly, other) in [(a, b), (b, a)] {
        for v in poly {
            for i in other.indices {
                near = min(near, edgeDistance(v, other[i], other[(i + 1) % other.count]))
            }
        }
    }
    return (overlaps(a, b) ? -near : near) - 2 * bubbleRadius
}

/// The shallowest lean that still leaves daylight between the pair.
///
/// Both tails stay pinned to their thumbs, so leaning further is the only way
/// out of an overlap, which makes the gap monotonic in the lean and a bisection
/// the right way to find it.
func leanApart(
    loBox: BubbleBox,
    hiBox: BubbleBox,
    loTilt: Double,
    hiTilt: Double,
    loX: Double,
    hiX: Double
) -> Double {
    func gapAt(_ lean: Double) -> Double {
        gap(
            between: corners(of: loBox, tilt: loTilt - lean, x: loX),
            and: corners(of: hiBox, tilt: hiTilt + lean, x: hiX)
        )
    }

    if gapAt(0) >= shoveClear { return 0 }

    var under = 0.0
    var over = shoveLean
    for _ in 0 ..< 12 {
        let mid = (under + over) / 2
        if gapAt(mid) < shoveClear { under = mid } else { over = mid }
    }
    return over
}
