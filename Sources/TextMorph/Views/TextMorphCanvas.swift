// Drawing a plan.
//
// One glyph run per segment, taken out of the whole-line shaping, under the
// transform the plan gives it. The probe that settled this compared pixels: a
// value drawn this way is identical to the same line drawn whole, and identical
// to a SwiftUI Text, at every system text style.
//
// Everything that moves is read inside the draw closure and nowhere else, so a
// frame never invalidates the layout.

import CoreGraphics
import CoreText
import SwiftUI

/// The canvas a morph is drawn on.
struct TextMorphCanvas: View {
    let plan: MorphPlan
    let frame: MorphFrame
    let ghosts: [(plan: MorphPlan, frame: MorphFrame)]
    let store: LayoutStore
    /// The container's size, which is the coordinate space the plan works in.
    let size: MorphSize
    /// What the glyphs are filled with.
    ///
    /// Resolved by the view rather than read here, because `.foregroundStyle`
    /// is not something a view can read back out of the environment. See
    /// `textMorphColor(_:)`.
    let colour: Color.Resolved
    let debug: Bool

    /// How far outside the container a morph is allowed to draw.
    ///
    /// The furthest any segment travels, plus the curve's overshoot, and never
    /// less than one slide. The default bezier overshoots by nothing, but the
    /// default spring bounces about sixteen percent past its target, and a
    /// glyph clipped at the peak of its bounce is a bug that only appears with
    /// springs.
    ///
    /// The canvas is grown by this on every side and then pulled back into
    /// place, rather than inset and outset: insetting moves the canvas's own
    /// origin, which quietly shifts every glyph by the same amount and makes
    /// the drawing wrong in a way that only a pixel comparison catches.
    var bleed: Double {
        let travel = plan.segments.reduce(0.0) { widest, animation in
            max(widest, abs(animation.from.dx), abs(animation.from.dy))
        }
        // Rounded up to a whole point, so the canvas is offset by a whole
        // number and its bitmap lands on the same subpixel grid a plain draw
        // would. A fractional offset rasterises every glyph at a different
        // phase, which reads as a faint softness and is invisible until two
        // renderings are compared.
        return max(plan.slideDistance, travel * (1 + plan.overshoot)).rounded(.up)
    }

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { context, _ in
            context.withCGContext { cg in
                cg.translateBy(x: bleed, y: bleed)
                cg.setFillColor(CGColor(
                    red: CGFloat(colour.red), green: CGFloat(colour.green),
                    blue: CGFloat(colour.blue), alpha: CGFloat(colour.opacity)
                ))
                // Oldest first, so a segment still leaving from an interrupted
                // morph sits under the one taking its place.
                for ghost in ghosts {
                    draw(ghost.plan, ghost.frame, in: cg, leavingOnly: true)
                }
                draw(plan, frame, in: cg, leavingOnly: false)
            }
        }
        .frame(width: size.width + bleed * 2, height: size.height + bleed * 2)
        .allowsHitTesting(false)
    }

    private func draw(
        _ plan: MorphPlan, _ frame: MorphFrame, in cg: CGContext, leavingOnly: Bool
    ) {
        for (animation, state) in zip(plan.segments, frame.states) {
            if leavingOnly, !animation.role.isLeaving { continue }
            if state.opacity <= 0 { continue }
            if animation.string.isEmpty { continue }

            if animation.role.isNumber {
                drawSlot(animation, state, plan: plan, in: cg)
            } else {
                drawSegment(animation, state, in: cg)
            }
            if debug { outline(animation, state, in: cg) }
        }
    }

    // MARK: - an ordinary segment

    private func drawSegment(
        _ animation: SegmentAnimation, _ state: SegmentState, in cg: CGContext
    ) {
        let shaped = store.shapedLine(for: animation.box.lineText)
        let glyphs = shaped.glyphs(in: animation.box.range)
        guard !glyphs.isEmpty else { return }

        cg.saveGState()
        cg.setAlpha(state.opacity)
        apply(transform: state, origin: animation.scaleOrigin, in: cg)
        shaped.draw(glyphs, at: baselineOrigin(animation), in: cg)
        cg.restoreGState()
    }

    // MARK: - a character of a number, in its slot

    /// The slot takes the displacement, the character inside it takes the
    /// slide, and the slide is clipped to the slot.
    ///
    /// Keeping the slide off the slot is what lets a digit cross a whole line
    /// box without the next morph measuring it as having moved. The clip is
    /// extended sideways so a glyph's overhang is not shaved off, and its top
    /// and bottom edges are softened, because a digit appearing at a hard line
    /// reads as a cut rather than as a roll.
    private func drawSlot(
        _ animation: SegmentAnimation, _ state: SegmentState,
        plan _: MorphPlan, in cg: CGContext
    ) {
        let shaped = store.shapedLine(for: animation.box.lineText)
        let glyphs = shaped.glyphs(in: animation.box.range)
        guard !glyphs.isEmpty else { return }

        let box = animation.box
        let overhang = box.height
        let slot = CGRect(
            x: box.x + state.dx - overhang,
            y: box.y + state.dy,
            width: box.width + overhang * 2,
            height: box.height
        )

        cg.saveGState()
        cg.clip(to: slot)
        cg.setAlpha(state.opacity)
        // Softening the edges needs the glyphs and the mask in one layer, so
        // the mask cannot eat what is drawn outside the slot.
        cg.beginTransparencyLayer(auxiliaryInfo: nil)

        var origin = baselineOrigin(animation)
        origin.x += state.dx
        origin.y += state.dy + state.moverDy
        shaped.draw(glyphs, at: origin, in: cg)

        softEdges(of: slot, em: CTFontGetSize(store.ctFont), in: cg)

        cg.endTransparencyLayer()
        cg.restoreGState()
    }

    /// Fades the top and bottom of a slot, by drawing a vertical gradient over
    /// what is already there and keeping only where the gradient is opaque.
    ///
    /// The band is in ems, so it is a share of the font's size rather than of
    /// the line box, and it is applied whether or not anything is sliding.
    /// Upstream masks the slot rather than animating the mask, positionally
    /// rather than on a timer, so the softness stays in step with the slide at
    /// any duration. The consequence is that a digit at rest is very slightly
    /// soft at the top and bottom, and that is upstream's look rather than an
    /// artefact of this port.
    private func softEdges(of slot: CGRect, em: Double, in cg: CGContext) {
        let band = em * MorphTiming.slotFade
        guard band > 0, slot.height > band * 2 else { return }

        let stops: [CGFloat] = [
            0,
            CGFloat(band / slot.height),
            CGFloat(1 - band / slot.height),
            1
        ]
        let colours = [
            CGColor(gray: 0, alpha: 0),
            CGColor(gray: 0, alpha: 1),
            CGColor(gray: 0, alpha: 1),
            CGColor(gray: 0, alpha: 0)
        ]
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceGray(),
            colors: colours as CFArray,
            locations: stops
        ) else { return }

        cg.saveGState()
        cg.setBlendMode(.destinationIn)
        cg.clip(to: slot)
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: slot.midX, y: slot.minY),
            end: CGPoint(x: slot.midX, y: slot.maxY),
            options: []
        )
        cg.restoreGState()
    }

    // MARK: - the transforms

    /// Where a segment's *line* origin sits, which is what its glyphs are
    /// positioned relative to.
    ///
    /// The x is the line's, not the segment's: a shaper reports a glyph's
    /// position within the line it shaped, so the segment's own offset is
    /// already in there. Using the segment's `x` counts it twice.
    private func baselineOrigin(_ animation: SegmentAnimation) -> CGPoint {
        let shaped = store.shapedLine(for: animation.box.lineText)
        return CGPoint(
            x: animation.box.lineOrigin,
            y: animation.box.y + shaped.metrics.ascent
        )
    }

    /// The displacement, and the scale about whatever the plan said to scale
    /// about: the segment's own centre, or a whole run's shared one.
    private func apply(transform state: SegmentState, origin: MorphPoint, in cg: CGContext) {
        cg.translateBy(x: state.dx, y: state.dy)
        guard state.scale != 1 else { return }
        cg.translateBy(x: origin.x, y: origin.y)
        cg.scaleBy(x: state.scale, y: state.scale)
        cg.translateBy(x: -origin.x, y: -origin.y)
    }

    // MARK: - debug

    /// Draws each segment's box, so the layout can be checked by eye.
    private func outline(
        _ animation: SegmentAnimation, _ state: SegmentState, in cg: CGContext
    ) {
        cg.saveGState()
        cg.setAlpha(0.5)
        cg.setLineWidth(0.5)
        cg.setStrokeColor(Self.debugColour(for: animation.role))
        cg.stroke(CGRect(
            x: animation.box.x + state.dx,
            y: animation.box.y + state.dy,
            width: animation.box.width,
            height: animation.box.height
        ))
        cg.restoreGState()
    }

    /// A colour per role, so what is happening is readable rather than merely
    /// visible.
    private static func debugColour(for role: SegmentRole) -> CGColor {
        switch role {
        case .persist, .numberPersist: CGColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)
        case .enter, .numberEnter, .groupEnter: CGColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1)
        case .exit, .numberExit, .groupExit: CGColor(red: 1, green: 0.4, blue: 0.3, alpha: 1)
        }
    }
}
