import Foundation

/// The fixtures generated from the published torph package by
/// `Tools/gen-goldens.mjs`.
///
/// The Android twin carries a byte-identical copy of the JSON and mirrors these
/// types, so a divergence between the two ports is a failing test rather than a
/// discovery months later.
struct Goldens: Decodable {
    let torphVersion: String
    let nodeUnicodeVersion: String
    let segmentText: [GoldenSegmentTextCase]
    let diffSegments: [GoldenDiffCase]
    let numberRules: GoldenNumberRules
    let segmentNumber: GoldenSegmentNumber
}

/// How upstream cuts one value into segments.
struct GoldenSegmentTextCase: Decodable {
    let value: String
    let numbers: Bool
    /// Set when this port is known to disagree, and why.
    ///
    /// The only such case is a run of CJK letters in a value that holds a space
    /// elsewhere: ICU joins the run into one word, and UAX #29 without
    /// dictionary breaking does not. The case is still recorded, so the
    /// difference lives in the fixture rather than in a comment.
    let diverges: String?
    let segments: [GoldenSegment]
}

/// How upstream matches one value against the segmentation of another.
struct GoldenDiffCase: Decodable {
    let before: String
    let after: String
    let numbers: Bool
    let cursor: Int?
    /// The identities of the old segmentation, in order, so the case is
    /// self-contained: the port builds the same starting point rather than
    /// being trusted to.
    let previous: [String]
    let segments: [GoldenSegment]
    /// The index in the old segmentation each new segment carries on from.
    let alignment: [Int?]
    /// Old spans that were cut finer to make the match.
    let splits: [String: [GoldenSplitSegment]]
}

/// A segment inside a split, which never carries a kind.
struct GoldenSplitSegment: Decodable, Equatable {
    let id: String
    let string: String
}

/// A segment as upstream reports it, with minted identities canonicalised to
/// `#0`, `#1` and so on in order of first appearance.
struct GoldenSegment: Decodable, Equatable {
    let id: String
    let string: String
    let kind: String?
}

/// Which tokens upstream reads as a quantity, and what it calls the decimal
/// separator in each locale of the corpus.
struct GoldenNumberRules: Decodable {
    struct NumericWordCase: Decodable {
        let token: String
        let result: Bool
    }

    struct SeparatorCase: Decodable {
        let locale: String
        let separator: String
    }

    let isNumericWord: [NumericWordCase]
    let decimalSeparator: [SeparatorCase]
}

/// How upstream cuts a numeric word, and which character of the old value each
/// character of the new one continues.
struct GoldenSegmentNumber: Decodable {
    /// A number with nothing to carry from.
    struct FreshCase: Decodable {
        let value: String
        let segments: [GoldenSegment]
    }

    /// A number continuing another, matched by place value.
    ///
    /// `alignment[i]` is the index in the old segmentation that the new segment
    /// at `i` carries on from, or nil if it arrived. Indices rather than
    /// identities, so the case says nothing about how either side mints them.
    struct PlaceCase: Decodable {
        let before: String
        let after: String
        let strings: [String]?
        let kinds: [String]?
        let alignment: [Int?]
    }

    /// The same, matched by caret instead.
    struct CursorCase: Decodable {
        let before: String
        let after: String
        let cursor: Int
        let strings: [String]
        let alignment: [Int?]
    }

    let fresh: [FreshCase]
    let place: [PlaceCase]
    let placeComma: [PlaceCase]
    let cursor: [CursorCase]
}
