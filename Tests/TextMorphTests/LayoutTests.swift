import CoreText
import Foundation
import Testing
@testable import TextMorph

/// The layout, and the claim the whole rendering design rests on.
///
/// The claim is that a value can be cut into segments, each drawn from the
/// whole-line shaping, and come out identical to the line drawn whole. The
/// probe that settled it compared pixels; what can be asserted here is the
/// arithmetic half of it: that reassembling the segments' widths lands exactly
/// on the line's own width, and that measuring a segment on its own does not.
@Suite("Layout and shaping")
struct LayoutTests {
    let corpus = [
        "AVATAR Wave",
        "1,234.56",
        "$1,234.56",
        "Total balance",
        "Wa To Ay LT AV",
        "0123456789",
        "3.5 km/h",
        "Hello, world!"
    ]

    private func font(_ size: Double) -> CTFont {
        TextMorphFont.system(size: size).resolve().ctFont
    }

    @Test("Reassembling the segments lands exactly on the line's own width")
    func reassemblyIsExact() {
        for size in [11.0, 17.0, 26.0, 48.0] {
            let resolved = font(size)
            for value in corpus {
                let segments = TextSegmenter.segmentText(value)
                let lines = LineLayout.lines(of: segments)
                let shaped = lines.map { GlyphRunShaper.shape($0.text, font: resolved) }
                let layout = LineLayout.layout(
                    lines: lines, metrics: shaped.map(\.metrics)
                )

                let reassembled = layout.boxes.reduce(0) { $0 + $1.width }
                #expect(
                    reassembled == shaped[0].metrics.width,
                    Comment(rawValue: "\(value) at \(size)pt:"
                        + " segments sum to \(reassembled), line is \(shaped[0].metrics.width)")
                )
            }
        }
    }

    @Test("Measuring each segment on its own drifts, which is why nothing does")
    func isolatedMeasurementDrifts() {
        // The number the probe measured, asserted so the fallacy stays
        // documented in something that runs rather than in a comment.
        let resolved = font(26)
        let value = "AVATAR Wave"
        let whole = GlyphRunShaper.shape(value, font: resolved).metrics.width
        let isolated = value.reduce(0.0) {
            $0 + GlyphRunShaper.shape(String($1), font: resolved).metrics.width
        }
        #expect(isolated > whole + 10, "isolated advances gained \(isolated - whole)pt")
        #expect(whole > 100)
    }

    @Test("Every glyph belongs to exactly one segment")
    func glyphsPartitionTheLine() {
        let resolved = font(17)
        for value in corpus {
            let segments = TextSegmenter.segmentText(value)
            let lines = LineLayout.lines(of: segments)
            let shaped = GlyphRunShaper.shape(lines[0].text, font: resolved)
            let layout = LineLayout.layout(lines: lines, metrics: [shaped.metrics])

            var claimed = 0
            for box in layout.boxes {
                claimed += shaped.glyphs(in: box.range).count
            }
            #expect(
                claimed == shaped.glyphs.count,
                Comment(rawValue: "\(value): \(claimed) of \(shaped.glyphs.count) glyphs claimed")
            )
        }
    }

    @Test("A line exists only where the value put one")
    func noAutomaticWrapping() {
        // However wide it gets. Wrapping instead would change which segments
        // are adjacent, and so change the whole morph.
        let long = String(repeating: "a very long value ", count: 40)
        #expect(LineLayout.lines(of: TextSegmenter.segmentText(long)).count == 1)

        #expect(LineLayout.lines(of: TextSegmenter.segmentText("a\nb")).count == 2)
        #expect(LineLayout.lines(of: TextSegmenter.segmentText("a\nb\nc")).count == 3)
        // An empty line at either end is still a line.
        #expect(LineLayout.lines(of: TextSegmenter.segmentText("\na")).count == 2)
        #expect(LineLayout.lines(of: TextSegmenter.segmentText("a\n")).count == 2)
        #expect(LineLayout.lines(of: TextSegmenter.segmentText("")).count == 1)
    }

    @Test("A multi-line value stacks by one line height, and slides by it")
    func multilineStacking() {
        let resolved = font(17)
        let segments = TextSegmenter.segmentText("one two\nthree four\nfive")
        let lines = LineLayout.lines(of: segments)
        let shaped = lines.map { GlyphRunShaper.shape($0.text, font: resolved) }
        let layout = LineLayout.layout(lines: lines, metrics: shaped.map(\.metrics))

        #expect(layout.lineCount == 3)
        #expect(layout.height == 3 * layout.lineHeight)
        // What a digit slides by, and what upstream derives by dividing the
        // container's height by the line count.
        #expect(layout.slideDistance == layout.height / Double(layout.lineCount))

        for box in layout.boxes {
            #expect(box.y == Double(box.line) * layout.lineHeight)
        }
        // The widest line sets the container's width.
        #expect(layout.width == shaped.map(\.metrics.width).max())
    }

    @Test("Alignment moves the lines, not the segments within them")
    func alignment() {
        let resolved = font(17)
        let segments = TextSegmenter.segmentText("short\nmuch longer line")
        let lines = LineLayout.lines(of: segments)
        let shaped = lines.map { GlyphRunShaper.shape($0.text, font: resolved) }
        let widths = shaped.map(\.metrics.width)

        let leading = LineLayout.layout(lines: lines, metrics: shaped.map(\.metrics))
        let centre = LineLayout.layout(
            lines: lines, metrics: shaped.map(\.metrics), alignment: .centre
        )
        let trailing = LineLayout.layout(
            lines: lines, metrics: shaped.map(\.metrics), alignment: .trailing
        )

        // The long line sets the width, so it does not move at all.
        let longLineFirst = { (layout: MorphLayout) in
            layout.boxes.first { $0.line == 1 }?.x ?? .nan
        }
        #expect(longLineFirst(leading) == 0)
        #expect(longLineFirst(centre) == 0)
        #expect(longLineFirst(trailing) == 0)

        let shortLineFirst = { (layout: MorphLayout) in
            layout.boxes.first { $0.line == 0 }?.x ?? .nan
        }
        #expect(shortLineFirst(leading) == 0)
        #expect(shortLineFirst(centre) == (widths[1] - widths[0]) / 2)
        #expect(shortLineFirst(trailing) == widths[1] - widths[0])
    }

    @Test("The first baseline is the first line's ascent, so a Text lines up")
    func firstBaseline() {
        let resolved = font(26)
        let segments = TextSegmenter.segmentText("Total")
        let lines = LineLayout.lines(of: segments)
        let shaped = GlyphRunShaper.shape(lines[0].text, font: resolved)
        let layout = LineLayout.layout(lines: lines, metrics: [shaped.metrics])
        #expect(layout.firstBaseline == shaped.metrics.ascent)
        #expect(layout.firstBaseline > 0)
        #expect(layout.firstBaseline < layout.lineHeight)
    }

    @Test("Pinning the container's width is what holds a centred value still")
    func pinnedContainerWidth() {
        // The first frame of a morph is laid out at the width the container had
        // a moment ago. Without it, a centred value shifts sideways the instant
        // the new value is narrower, and every segment appears to move.
        let resolved = font(17)
        let segments = TextSegmenter.segmentText("short")
        let lines = LineLayout.lines(of: segments)
        let shaped = GlyphRunShaper.shape(lines[0].text, font: resolved)

        let natural = LineLayout.layout(
            lines: lines, metrics: [shaped.metrics], alignment: .centre
        )
        let pinned = LineLayout.layout(
            lines: lines, metrics: [shaped.metrics], alignment: .centre,
            containerWidth: shaped.metrics.width + 100
        )

        #expect(natural.boxes[0].x == 0)
        #expect(pinned.boxes[0].x == 50)
    }
}
