// Shaping each line once and keeping it.
//
// A morph reshapes nothing per frame. The value changes at most a few times a
// second and the frames come at up to a hundred and twenty, so shaping belongs
// behind a cache keyed on everything that could change the answer.

import CoreText
import Foundation
import SwiftUI

/// Measuring a line, which is all the layout needs.
///
/// A protocol so the plan can be tested against a made-up monospace metric
/// where a displacement is a whole number, rather than against whatever the
/// machine running the tests happens to have installed.
///
/// Isolated to the main actor because the store it stands for is: it belongs to
/// one view and is read from the draw path, so making it shareable would mean a
/// lock for no reason.
@MainActor
protocol LineMeasuring {
    func metrics(for text: String) -> ShapedLineMetrics
}

/// Shaped lines, kept until the font changes.
///
/// Not thread safe, and deliberately so: it belongs to one view's engine, which
/// lives on the main actor. Making it safe to share would mean a lock on the
/// draw path for no reason.
@MainActor
final class LayoutStore: LineMeasuring {
    /// Everything that changes what a line measures.
    ///
    /// The size category is in here rather than being folded into the font,
    /// because a change to it has to invalidate every line at once.
    private struct Key: Hashable {
        let text: String
        let font: TextMorphFont
        let dynamicTypeSize: DynamicTypeSize
    }

    private var font: TextMorphFont
    private var dynamicTypeSize: DynamicTypeSize
    private var resolved: TextMorphFont.Resolved
    private var lines: [Key: ShapedLine] = [:]

    /// How many lines to keep. A morph touches at most a handful at a time, and
    /// a ticker walking through values would otherwise grow this without bound.
    private static let capacity = 256

    init(font: TextMorphFont = .body, dynamicTypeSize: DynamicTypeSize = .large) {
        self.font = font
        self.dynamicTypeSize = dynamicTypeSize
        resolved = font.resolve(dynamicTypeSize: dynamicTypeSize)
    }

    /// Whether the named face could not be found and the system face stood in.
    var isSubstituted: Bool { resolved.substituted }

    /// The font every line is shaped with.
    var ctFont: CTFont { resolved.ctFont }

    /// Points the store at a different font, dropping what it knew.
    func use(font: TextMorphFont, dynamicTypeSize: DynamicTypeSize) {
        guard font != self.font || dynamicTypeSize != self.dynamicTypeSize else { return }
        self.font = font
        self.dynamicTypeSize = dynamicTypeSize
        resolved = font.resolve(dynamicTypeSize: dynamicTypeSize)
        lines.removeAll(keepingCapacity: true)
    }

    /// One line, shaped.
    func shapedLine(for text: String) -> ShapedLine {
        let key = Key(text: text, font: font, dynamicTypeSize: dynamicTypeSize)
        if let cached = lines[key] { return cached }

        // Emptied rather than evicted one at a time. A morph reshapes a whole
        // value at once, so a least-recently-used order would be thrown away by
        // the next update anyway, and the cost of being wrong is one reshape.
        if lines.count >= Self.capacity { lines.removeAll(keepingCapacity: true) }

        let shaped = GlyphRunShaper.shape(text, font: resolved.ctFont)
        lines[key] = shaped
        return shaped
    }

    func metrics(for text: String) -> ShapedLineMetrics {
        shapedLine(for: text).metrics
    }
}

extension LineMeasuring {
    /// Lays a value's segments out, measuring each line once.
    func layout(
        _ segments: [Segment],
        alignment: MorphAlignment,
        containerWidth: Double? = nil
    ) -> MorphLayout {
        let lines = LineLayout.lines(of: segments)
        return LineLayout.layout(
            lines: lines,
            metrics: lines.map { metrics(for: $0.text) },
            alignment: alignment,
            containerWidth: containerWidth
        )
    }
}
