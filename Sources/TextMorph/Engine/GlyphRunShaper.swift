// Shaping a line once, and drawing any part of it.
//
// This is the approach the rendering probe settled on, and the numbers are
// worth keeping next to the code. Drawing one glyph run per segment, with the
// glyphs, advances and positions all taken out of the runs of the whole-line
// `CTLine`, is identical to a single `CTLineDraw` of the whole value: zero
// differing pixels at every system text style. It is also identical to SwiftUI
// `Text`, once both are given the same fill colour and the baseline sits at the
// line's ascent.
//
// Measuring each segment on its own instead does not work, and not marginally:
// summing per-character advances gains 11.29pt on 157pt at 26pt, and 21.09pt on
// 287pt at 48pt, because the error accumulates. Measuring cumulative prefixes
// stays under 1.7pt and lands exactly on the whole-line width, so it is a
// usable fallback where CoreText is not available; summing isolated advances
// never is.

import CoreGraphics
import CoreText
import Foundation

/// One line of a value, shaped.
struct ShapedLine {
    /// The line's text, so a cache can tell two shapings apart.
    let text: String
    /// What the line measured.
    let metrics: ShapedLineMetrics
    /// Every glyph, in the order CoreText laid them out.
    let glyphs: [ShapedGlyph]
}

/// One glyph of a shaped line.
struct ShapedGlyph {
    let glyph: CGGlyph
    /// Relative to the line's origin, with y increasing upwards, which is what
    /// CoreText reports and what `CTFontDrawGlyphs` expects.
    let position: CGPoint
    /// The first UTF-16 index this glyph covers.
    ///
    /// A ligature covers several, and CoreText reports the first of them, so a
    /// ligature straddling a segment boundary belongs to whichever segment its
    /// first character is in. That is better than the web original, where an
    /// inline-block boundary suppresses the ligature outright.
    let utf16Index: Int
    /// The font of the run this glyph came from, which is not always the font
    /// asked for: CoreText substitutes for a character the face does not cover.
    let font: CTFont
}

/// Shaping with CoreText.
enum GlyphRunShaper {
    /// Shapes one line.
    ///
    /// Ligature formation is left at the platform's default. On Apple platforms
    /// that means the system face forms none of the fi or fl ligatures, so a
    /// segment boundary inside one is not a live problem here; the Android twin
    /// has to disable the features explicitly, because Roboto does form them
    /// and drawing character by character would then differ from drawing the
    /// line whole.
    static func shape(_ text: String, font: CTFont) -> ShapedLine {
        let attributed = NSAttributedString(
            string: text, attributes: [.font: font]
        )
        let line = CTLineCreateWithAttributedString(attributed)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        // Every UTF-16 boundary, from the whole-line shaping. Bidi aware,
        // because CoreText resolved the line before answering.
        let length = text.utf16.count
        var offsets: [Double] = []
        offsets.reserveCapacity(length + 1)
        for boundary in 0 ... length {
            offsets.append(Double(CTLineGetOffsetForStringIndex(line, CFIndex(boundary), nil)))
        }

        return ShapedLine(
            text: text,
            metrics: ShapedLineMetrics(
                width: width,
                ascent: Double(ascent),
                descent: Double(descent),
                leading: Double(leading),
                offsets: offsets
            ),
            glyphs: glyphs(of: line, fallback: font)
        )
    }

    /// Every glyph of a line, flattened out of its runs.
    private static func glyphs(of line: CTLine, fallback: CTFont) -> [ShapedGlyph] {
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return [] }

        var out: [ShapedGlyph] = []
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }

            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            let range = CFRangeMake(0, count)
            CTRunGetGlyphs(run, range, &glyphs)
            CTRunGetPositions(run, range, &positions)
            CTRunGetStringIndices(run, range, &indices)

            // CTFont and the platform's font type are toll-free bridged, so
            // reading the run's font back out as one is safe, including for a
            // run CoreText substituted a different face into.
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = (attributes[kCTFontAttributeName as String] as? PlatformFont)
                .map { $0 as CTFont } ?? fallback

            out.reserveCapacity(out.count + count)
            for position in 0 ..< count {
                out.append(ShapedGlyph(
                    glyph: glyphs[position],
                    position: positions[position],
                    utf16Index: Int(indices[position]),
                    font: runFont
                ))
            }
        }
        return out
    }
}

extension ShapedLine {
    /// The glyphs of one UTF-16 range, which is one segment's worth.
    func glyphs(in range: Range<Int>) -> [ShapedGlyph] {
        glyphs.filter { range.contains($0.utf16Index) }
    }

    /// Draws part of the line.
    ///
    /// `origin` is where the line's own origin should land, in the context's
    /// coordinates, with y increasing downwards; the baseline is placed at
    /// `origin.y`. The context is expected to carry any transform the segment
    /// needs already.
    func draw(_ glyphs: [ShapedGlyph], at origin: CGPoint, in context: CGContext) {
        guard !glyphs.isEmpty else { return }

        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: origin.x, y: origin.y)
        // CoreText reports positions with y upwards; the context has y
        // downwards, so the axis is flipped once here rather than negated at
        // every glyph.
        context.scaleBy(x: 1, y: -1)

        // Grouped by font so a substituted run does not cost a state change per
        // glyph.
        var index = 0
        while index < glyphs.count {
            let font = glyphs[index].font
            var run: [CGGlyph] = []
            var positions: [CGPoint] = []
            while index < glyphs.count, glyphs[index].font == font {
                run.append(glyphs[index].glyph)
                positions.append(CGPoint(
                    x: glyphs[index].position.x, y: -glyphs[index].position.y
                ))
                index += 1
            }
            CTFontDrawGlyphs(font, run, positions, run.count, context)
        }

        context.restoreGState()
    }
}
