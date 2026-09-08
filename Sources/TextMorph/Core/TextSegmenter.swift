// A port of torph's packages/torph/src/lib/text-morph/utils/segment.ts.

import Foundation

/// The locale upstream defaults to.
///
/// Deliberately not `Locale.current`: the segmentation and the formatting of a
/// number both depend on it, so taking it from the device would make the same
/// value morph differently on two phones, and would make a fixture
/// unreproducible.
public let defaultMorphLocale = Locale(identifier: "en")

/// Cutting a value into the segments a morph is expressed in.
public enum TextSegmenter {
    /// Splits a value into segments.
    ///
    /// The unit depends on the value. One that holds a space or a line break is
    /// cut into words, because words are what a reader tracks across a change
    /// of sentence. One that does not is cut into grapheme clusters, because a
    /// single word changing is a change of letters. That is upstream's rule and
    /// it is why a counter, a price or a label morphs per character.
    ///
    /// With `numbers` on, a second pass re-cuts every numeric word into
    /// per-character segments carrying a kind, so it can morph by place value.
    /// It is a pass over the finished segmentation rather than part of it,
    /// because the word segmenter splits `$1,234` on its own terms and
    /// regrouping on whitespace is what keeps this and the diff agreeing.
    ///
    /// `locale` is accepted for parity with upstream's signature, and because
    /// the rest of the engine needs it, but it has no effect on where the
    /// boundaries fall. Upstream hands segmentation to `Intl.Segmenter`, whose
    /// answer is locale-dependent for the languages ICU carries a dictionary
    /// for; these rules are UAX #29 without dictionary breaking and are the
    /// same for every locale. Where the locale does decide something is the
    /// decimal separator and the formatting of a numeric value.
    public static func segmentText(
        _ value: String,
        locale: Locale = defaultMorphLocale,
        numbers: Bool = true
    ) -> [Segment] {
        segmentText(value, locale: locale, numbers: numbers, minter: MintedIds())
    }

    /// The locale is threaded through for the caller's benefit; see the note on
    /// the public overload for why the boundaries do not depend on it.
    static func segmentText(
        _ value: String,
        locale _: Locale,
        numbers: Bool,
        minter: MintedIds
    ) -> [Segment] {
        let hasNewlines = value.contains("\n")
        let byWord = value.contains(" ") || hasNewlines
        var allocator = IdAllocator()

        guard hasNewlines else {
            let segments = segmentLine(
                value, byWord: byWord, offset: UTF16Offset(0), allocator: &allocator
            )
            return numbers ? expandNumbers(segments, minter: minter) : segments
        }

        // The offset indexes the whole value, not the line, so identities
        // derived from it stay unique across lines.
        var segments: [Segment] = []
        var offset = UTF16Offset(0)
        let lines = value.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            if index > 0 {
                segments.append(Segment(id: allocator.take("newline-\(offset)"), string: "\n"))
                offset += 1
            }
            if !line.isEmpty {
                // A value with a line break is cut into words on every line,
                // even a line that holds no space. So "a\nb" and "ab" segment
                // differently, which is upstream behaviour and is pinned.
                segments.append(contentsOf: segmentLine(
                    line, byWord: true, offset: offset, allocator: &allocator
                ))
            }
            offset += line.utf16Length.value
        }

        return numbers ? expandNumbers(segments, minter: minter) : segments
    }

    /// Whitespace-delimited words: the unit the diff aligns on, and so a
    /// number's bounds.
    ///
    /// Only a normalised space or a line break separates. A run of two or more
    /// spaces is one segment holding ordinary spaces, and therefore does not
    /// separate, so `"hello  double"` is a single group here while the diff
    /// splits the new value on single spaces. That asymmetry is upstream's.
    static func groupIntoWords(_ segments: [Segment]) -> [(word: String, segments: [Segment])] {
        var groups: [(word: String, segments: [Segment])] = []
        var current: [Segment] = []

        func flush() {
            guard !current.isEmpty else { return }
            groups.append((word: current.map(\.string).joined(), segments: current))
            current = []
        }

        for segment in segments {
            if segment.isWordSeparator || segment.isNewline {
                flush()
            } else {
                current.append(segment)
            }
        }
        flush()

        return groups
    }
}

// MARK: - one line

private extension TextSegmenter {
    static func segmentLine(
        _ line: String,
        byWord: Bool,
        offset: UTF16Offset,
        allocator: inout IdAllocator
    ) -> [Segment] {
        let boundaries = byWord
            ? UnicodeBreaks.wordBoundaries(of: line)
            : UnicodeBreaks.graphemeBoundaries(of: line)
        guard boundaries.count > 1 else { return [] }

        let units = Array(line.utf16)
        var segments: [Segment] = []
        segments.reserveCapacity(boundaries.count - 1)

        for position in 0 ..< boundaries.count - 1 {
            let start = boundaries[position].value
            let end = boundaries[position + 1].value
            guard let text = String(decoding: units[start ..< end]) else { continue }
            let index = offset + start

            if text == " " {
                segments.append(Segment(id: allocator.take("space-\(index)"), string: "\u{00A0}"))
            } else {
                segments.append(Segment(id: allocateId(text, at: index, &allocator), string: text))
            }
        }

        return segments
    }

    /// A segment's own text is its identity, and only a collision brings the
    /// index into it.
    static func allocateId(
        _ text: String, at index: UTF16Offset, _ allocator: inout IdAllocator
    ) -> String {
        allocator.has(text) ? allocator.take("\(text)-\(index)") : allocator.take(text)
    }

    /// Re-cuts every numeric word into per-character segments carrying a kind.
    static func expandNumbers(_ segments: [Segment], minter: MintedIds) -> [Segment] {
        var out: [Segment] = []
        var run: [Segment] = []

        func flush() {
            guard !run.isEmpty else { return }
            let word = run.map(\.string).joined()
            if NumberRules.isNumericWord(word) {
                out.append(contentsOf: NumberSegmenter
                    .segmentNumber(word, minter: minter)
                    .map(\.segment))
            } else {
                out.append(contentsOf: run)
            }
            run = []
        }

        for segment in segments {
            if segment.isWordSeparator || segment.isNewline {
                flush()
                out.append(segment)
            } else {
                run.append(segment)
            }
        }
        flush()

        return out
    }
}

private extension String {
    /// A run of UTF-16 units as a value, or nil if the run is not well formed.
    ///
    /// A boundary never falls inside a surrogate pair, so this cannot fail in
    /// practice; it returns an optional rather than substituting a replacement
    /// character, so a bug in the boundary rules shows up as a missing segment
    /// rather than as a rendered U+FFFD.
    init?(decoding units: ArraySlice<UInt16>) {
        var scalars = String.UnicodeScalarView()
        var decoder = UTF16()
        var iterator = units.makeIterator()
        while true {
            switch decoder.decode(&iterator) {
            case let .scalarValue(scalar): scalars.append(scalar)
            case .emptyInput: self = String(scalars); return
            case .error: return nil
            }
        }
    }
}
