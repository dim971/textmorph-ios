// The UAX #29 break rules, over the tables in UnicodeBreakTables.swift.
//
// Why these are ported rather than delegated: this library segments a value the
// way Intl.Segmenter does, and the two platforms' own ICU do not agree with
// each other about it. Foundation's `.byWords` breaks a CJK run by dictionary
// and stops reporting spaces as gaps once one appears; Android's android.icu
// gives a third answer; and both move with the OS version. Owning the rules is
// the only way the two ports can be held to the same fixture.
//
// Dictionary breaking is deliberately not implemented. For Japanese, Chinese,
// Thai, Khmer and Lao a run of letters stays one word here, where ICU would cut
// it into lexical words. Upstream already segments those languages by grapheme
// whenever the value has no space, which is the common case for this library,
// so the difference is confined to spaced CJK and is at least self-consistent.

/// Boundaries in a value, as UTF-16 offsets, following UAX #29.
enum UnicodeBreaks {
    /// Extended grapheme cluster boundaries, including 0 and the value's length.
    ///
    /// Returns a single boundary pair for an empty value, so callers can always
    /// read consecutive elements as a range.
    static func graphemeBoundaries(of value: String) -> [UTF16Offset] {
        let scalars = ScalarInfo.decode(value)
        return boundaries(of: value, scalars: scalars) { index in
            graphemeBreaks(scalars, before: index)
        }
    }

    /// Word boundaries, including 0 and the value's length.
    static func wordBoundaries(of value: String) -> [UTF16Offset] {
        let scalars = ScalarInfo.decode(value)
        // The folding rule WB4 is resolved once for the whole value, not per
        // boundary, so this is linear rather than quadratic.
        let breaker = WordBreaker(scalars)
        return boundaries(of: value, scalars: scalars) { index in
            breaker.breaks(before: index)
        }
    }

    /// GB1, GB2, WB1 and WB2: a value always breaks at both ends.
    private static func boundaries(
        of value: String,
        scalars: [ScalarInfo],
        breaksBefore: (Int) -> Bool
    ) -> [UTF16Offset] {
        if scalars.isEmpty { return [UTF16Offset(0)] }

        var offsets: [UTF16Offset] = [UTF16Offset(0)]
        for index in 1 ..< scalars.count where breaksBefore(index) {
            offsets.append(scalars[index].offset)
        }
        offsets.append(value.utf16Length)
        return offsets
    }
}

// MARK: - the value, decoded once

/// One scalar of a value, with the properties every rule needs and the UTF-16
/// offset a boundary is eventually reported at.
struct ScalarInfo {
    let scalar: Unicode.Scalar
    let offset: UTF16Offset
    let grapheme: GraphemeBreakProperty
    let word: WordBreakProperty
    let incb: IndicConjunctBreak
    let isExtendedPictographic: Bool

    /// Decodes a value once, so no rule pays for a table lookup twice.
    static func decode(_ value: String) -> [ScalarInfo] {
        var out: [ScalarInfo] = []
        out.reserveCapacity(value.unicodeScalars.count)
        var offset = 0
        for scalar in value.unicodeScalars {
            out.append(ScalarInfo(
                scalar: scalar,
                offset: UTF16Offset(offset),
                grapheme: UnicodeBreakTables.graphemeProperty(scalar),
                word: UnicodeBreakTables.wordProperty(scalar),
                incb: UnicodeBreakTables.indicConjunctBreakProperty(scalar),
                isExtendedPictographic: UnicodeBreakTables.isExtendedPictographic(scalar)
            ))
            offset += UTF16.width(scalar)
        }
        return out
    }
}

// MARK: - grapheme cluster boundaries

private extension UnicodeBreaks {
    // swiftlint:disable cyclomatic_complexity
    /// Whether a cluster boundary falls immediately before `index`.
    ///
    /// One branch per named rule of UAX #29, in the standard's own order. The
    /// three rules that need more than the two adjacent scalars walk backwards
    /// from `index` rather than carrying state, so this stays a pure function
    /// of the value. Splitting the chain to satisfy a complexity threshold
    /// would put a function boundary inside a rule sequence, and the sequence
    /// is the thing a reader has to check against the standard.
    static func graphemeBreaks(_ scalars: [ScalarInfo], before index: Int) -> Bool {
        let prev = scalars[index - 1]
        let next = scalars[index]

        // GB3
        if prev.grapheme == .cr, next.grapheme == .lf { return false }
        // GB4 and GB5
        if isControlLike(prev.grapheme) || isControlLike(next.grapheme) { return true }
        // GB6, GB7 and GB8: the Hangul syllable shapes
        if prev.grapheme == .l, [.l, .v, .lv, .lvt].contains(next.grapheme) { return false }
        if [.lv, .v].contains(prev.grapheme), [.v, .t].contains(next.grapheme) { return false }
        if [.lvt, .t].contains(prev.grapheme), next.grapheme == .t { return false }
        // GB9, GB9a and GB9b
        if next.grapheme == .extend || next.grapheme == .zwj { return false }
        if next.grapheme == .spacingMark { return false }
        if prev.grapheme == .prepend { return false }
        // GB9c: an Indic conjunct, which is one cluster across its linker
        if next.incb == .consonant, hasIndicLinkerRun(scalars, endingBefore: index) { return false }
        // GB11: an emoji ZWJ sequence
        if next.isExtendedPictographic, hasPictographicZWJ(scalars, endingBefore: index) { return false }
        // GB12 and GB13: regional indicators pair up from the start of the run
        if prev.grapheme == .regionalIndicator, next.grapheme == .regionalIndicator {
            return regionalIndicatorRun(scalars, endingBefore: index).isMultiple(of: 2)
        }
        // GB999
        return true
    }

    // swiftlint:enable cyclomatic_complexity

    static func isControlLike(_ property: GraphemeBreakProperty) -> Bool {
        property == .control || property == .cr || property == .lf
    }

    /// GB9c's left side: a consonant, then only Indic extends and linkers, with
    /// at least one linker among them.
    static func hasIndicLinkerRun(_ scalars: [ScalarInfo], endingBefore index: Int) -> Bool {
        var sawLinker = false
        var cursor = index - 1
        while cursor >= 0 {
            switch scalars[cursor].incb {
            case .linker:
                sawLinker = true
            case .extend:
                break
            case .consonant:
                return sawLinker
            case .none:
                return false
            }
            cursor -= 1
        }
        return false
    }

    /// GB11's left side: a pictograph, then any number of extends, then a ZWJ.
    static func hasPictographicZWJ(_ scalars: [ScalarInfo], endingBefore index: Int) -> Bool {
        guard index >= 1, scalars[index - 1].grapheme == .zwj else { return false }
        var cursor = index - 2
        while cursor >= 0, scalars[cursor].grapheme == .extend {
            cursor -= 1
        }
        return cursor >= 0 && scalars[cursor].isExtendedPictographic
    }

    /// How many regional indicators run consecutively up to, and including,
    /// `index - 1`. An even count means the pair before this one closed, so the
    /// next indicator starts a fresh flag.
    static func regionalIndicatorRun(_ scalars: [ScalarInfo], endingBefore index: Int) -> Int {
        var count = 0
        var cursor = index - 1
        while cursor >= 0, scalars[cursor].grapheme == .regionalIndicator {
            count += 1
            cursor -= 1
        }
        return count
    }
}
