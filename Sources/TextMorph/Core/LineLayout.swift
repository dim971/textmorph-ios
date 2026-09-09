// Where every segment of a value sits, once the text has been shaped.
//
// This has no upstream counterpart. Upstream lets the browser lay the spans out
// and then reads their boxes back; this port shapes each line once and computes
// the boxes, which is exact rather than a reflow it has to trust. What it must
// not lose is that there is no automatic line breaking: upstream's root is
// `white-space: nowrap`, so a line exists only where the value put one, and the
// container is free to overflow its parent.

/// What one line of a value measures, as the platform's text engine reports it.
///
/// `offsets` holds the x position of every UTF-16 boundary in the line, so it
/// is one longer than the line's UTF-16 length. Those come from shaping the
/// whole line once, never from measuring pieces of it: measuring a segment on
/// its own loses the kerning between it and its neighbours, and the error
/// accumulates to several percent of the line.
public struct ShapedLineMetrics: Hashable, Sendable {
    /// The line's advance width.
    public let width: Double
    /// Above the baseline.
    public let ascent: Double
    /// Below the baseline.
    public let descent: Double
    /// The gap the font asks for between this line and the next.
    public let leading: Double
    /// The x position of each UTF-16 boundary, from 0 to `width`.
    public let offsets: [Double]

    /// Creates line metrics.
    public init(width: Double, ascent: Double, descent: Double, leading: Double, offsets: [Double]) {
        self.width = width
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.offsets = offsets
    }

    /// The height of a line box: everything the font asks for.
    public var lineHeight: Double { ascent + descent + leading }
}

/// A size in the container's own coordinates.
///
/// Doubles rather than `CGSize`, so nothing in the engine's signatures depends
/// on CoreGraphics. The implicit conversion between `CGFloat` and `Double` is
/// also a nuisance to compare: two values with identical bit patterns can come
/// back unequal through it.
public struct MorphSize: Hashable, Sendable {
    public var width: Double
    public var height: Double

    /// Creates a size.
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// Nothing.
    public static let zero = MorphSize(width: 0, height: 0)
}

/// Where one segment sits in a laid-out value.
public struct SegmentBox: Hashable, Sendable {
    /// The segment's identity, which is how a box is found across two layouts.
    public let id: String
    /// The left edge, in the container's coordinates.
    public let x: Double
    /// The top of the line box, in the container's coordinates.
    public let y: Double
    /// The segment's advance width.
    public let width: Double
    /// The height of the line box the segment sits in.
    public let height: Double
    /// Which line, counting from zero.
    public let line: Int
    /// The segment's UTF-16 range within its own line, which is what the
    /// shaper needs to draw exactly these glyphs.
    public let range: Range<Int>

    /// The centre, which is what a run collapsing as one shape scales about.
    public var centre: MorphPoint {
        MorphPoint(x: x + width / 2, y: y + height / 2)
    }
}

/// How a value is laid out, and how big it turned out to be.
public struct MorphLayout: Sendable {
    /// Every drawable segment, in order. Line breaks are not here: they decide
    /// where the boxes go rather than being drawn themselves.
    public let boxes: [SegmentBox]

    /// The container's own width, which is the widest line.
    public let width: Double
    /// The container's own height: one line box per line.
    public let height: Double
    /// Where the first line's baseline sits, so a morph can be aligned with an
    /// ordinary piece of text beside it.
    public let firstBaseline: Double
    /// How many lines the value has. One more than the number of line breaks.
    public let lineCount: Int
    /// The height of one line box, which is what a digit slides by.
    public let lineHeight: Double

    private let index: [String: Int]

    init(
        boxes: [SegmentBox],
        width: Double,
        height: Double,
        firstBaseline: Double,
        lineCount: Int,
        lineHeight: Double
    ) {
        self.boxes = boxes
        self.width = width
        self.height = height
        self.firstBaseline = firstBaseline
        self.lineCount = lineCount
        self.lineHeight = lineHeight

        var index: [String: Int] = [:]
        index.reserveCapacity(boxes.count)
        for (position, box) in boxes.enumerated() {
            index[box.id] = position
        }
        self.index = index
    }

    /// The box for a segment, by identity.
    public subscript(id: String) -> SegmentBox? {
        index[id].map { boxes[$0] }
    }

    /// Every segment's top-left corner, which is what a displacement is
    /// measured between.
    var positions: SegmentPositions {
        var positions = SegmentPositions()
        for box in boxes {
            positions[box.id] = MorphPoint(x: box.x, y: box.y)
        }
        return positions
    }

    /// How far a digit slides when it enters or leaves a number.
    ///
    /// One line's worth. Upstream derives it by dividing the container's height
    /// by the line count, which is the same number by construction here.
    public var slideDistance: Double { lineHeight }
}

/// Which edge the lines of a multi-line value line up on.
public enum MorphAlignment: Hashable, Sendable {
    case leading
    case centre
    case trailing
}

/// Assembling a laid-out value from its segments and its measured lines.
public enum LineLayout {
    /// One line of a value: the segments on it, and the text they make.
    public struct Line: Sendable {
        /// The segments on this line, in order, line breaks excluded.
        public let segments: [Segment]
        /// The text of the line, which is what gets shaped.
        public let text: String

        /// The UTF-16 offset of each segment within the line, one per segment
        /// plus a final one at the line's length.
        public let offsets: [Int]
    }

    /// Splits a value's segments into lines.
    ///
    /// Only on the line-break segments, and never on anything else: there is no
    /// automatic wrapping here, deliberately. A value with no break is one
    /// line, however wide it is, and the container overflows rather than
    /// reflowing. That is upstream's behaviour, and reflowing instead would
    /// change which segments are adjacent and so change the whole morph.
    public static func lines(of segments: [Segment]) -> [Line] {
        var lines: [Line] = []
        var current: [Segment] = []

        func flush() {
            var text = ""
            var offsets: [Int] = []
            for segment in current {
                offsets.append(text.utf16.count)
                text += segment.string
            }
            offsets.append(text.utf16.count)
            lines.append(Line(segments: current, text: text, offsets: offsets))
            current = []
        }

        for segment in segments {
            if segment.isNewline {
                flush()
            } else {
                current.append(segment)
            }
        }
        flush()

        return lines
    }

    /// Places every segment, given what each line measured.
    ///
    /// `containerWidth` is what the alignment is measured against. Passing the
    /// natural width, which is the widest line, is what an unconstrained morph
    /// does; passing the width the container had a moment ago is how the first
    /// frame of a morph is laid out, which is the only thing that makes a
    /// centred or trailing value hold still while it changes.
    public static func layout(
        lines: [Line],
        metrics: [ShapedLineMetrics],
        alignment: MorphAlignment = .leading,
        containerWidth: Double? = nil
    ) -> MorphLayout {
        precondition(lines.count == metrics.count, "a line and its metrics come in pairs")

        // One height for every line box, so a digit's slide is the same
        // distance wherever it is and a line's position is a multiple of it.
        let lineHeight = metrics.map(\.lineHeight).max() ?? 0
        let ascent = metrics.first?.ascent ?? 0
        let naturalWidth = metrics.map(\.width).max() ?? 0
        let width = containerWidth ?? naturalWidth

        var boxes: [SegmentBox] = []
        for (lineIndex, line) in lines.enumerated() {
            let lineMetrics = metrics[lineIndex]
            let origin = originX(for: lineMetrics.width, in: width, alignment: alignment)
            let top = Double(lineIndex) * lineHeight

            for (position, segment) in line.segments.enumerated() {
                let start = line.offsets[position]
                let end = line.offsets[position + 1]
                let left = offset(lineMetrics, at: start)
                let right = offset(lineMetrics, at: end)
                boxes.append(SegmentBox(
                    id: segment.id,
                    x: origin + left,
                    y: top,
                    width: right - left,
                    height: lineHeight,
                    line: lineIndex,
                    range: start ..< end
                ))
            }
        }

        return MorphLayout(
            boxes: boxes,
            width: max(width, naturalWidth),
            height: Double(lines.count) * lineHeight,
            firstBaseline: ascent,
            lineCount: lines.count,
            lineHeight: lineHeight
        )
    }

    private static func originX(
        for lineWidth: Double, in containerWidth: Double, alignment: MorphAlignment
    ) -> Double {
        switch alignment {
        case .leading: 0
        case .centre: (containerWidth - lineWidth) / 2
        case .trailing: containerWidth - lineWidth
        }
    }

    /// A boundary's x position, clamped to what the metrics actually carry.
    ///
    /// The offsets should always reach the line's length, and a mismatch would
    /// be a bug in the shaper rather than in the value; clamping means such a
    /// bug shows up as a segment of the wrong width rather than as a crash in a
    /// draw pass.
    private static func offset(_ metrics: ShapedLineMetrics, at boundary: Int) -> Double {
        guard !metrics.offsets.isEmpty else { return 0 }
        return metrics.offsets[min(max(boundary, 0), metrics.offsets.count - 1)]
    }
}
