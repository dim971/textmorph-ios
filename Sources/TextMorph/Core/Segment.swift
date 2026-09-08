/// A position in a value, counted in UTF-16 code units.
///
/// Upstream indexes strings the way JavaScript does, in UTF-16 code units:
/// `String.length`, the `index` an `Intl.Segmenter` reports, and the caret
/// position a text field hands over are all counts of code units. Segment
/// identities are derived from those indices, so counting differently changes
/// every identity that carries one.
///
/// Swift's own natural unit is the extended grapheme cluster, which is a
/// different number for any value containing an astral character or a combining
/// mark. A distinct type is here so that number cannot be passed by accident:
/// nothing in `Core` takes a bare offset, and `String.utf16Length` is the only
/// way to get one from a value.
public struct UTF16Offset: Hashable, Comparable, Sendable,
    ExpressibleByIntegerLiteral, CustomStringConvertible {
    /// The offset, in UTF-16 code units from the start of the value.
    public let value: Int

    /// Creates an offset from a count of UTF-16 code units.
    public init(_ value: Int) { self.value = value }

    /// Creates an offset from a literal, so a constant reads as a number.
    public init(integerLiteral value: Int) { self.value = value }

    public var description: String { String(value) }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }

    public static func + (lhs: Self, rhs: Int) -> Self { Self(lhs.value + rhs) }

    public static func - (lhs: Self, rhs: Int) -> Self { Self(lhs.value - rhs) }

    public static func += (lhs: inout Self, rhs: Int) { lhs = lhs + rhs }
}

public extension String {
    /// The length upstream sees: a count of UTF-16 code units, like
    /// JavaScript's `String.length`.
    ///
    /// Prefer this over `count`, which counts grapheme clusters and disagrees
    /// on any value holding an astral character.
    var utf16Length: UTF16Offset { UTF16Offset(utf16.count) }
}

/// Why a segment moves the way it does.
///
/// A segment with a kind belongs to a numeric word, and slides along the block
/// axis by place value rather than fading in place. Digits and the symbols
/// around them slide opposite ways, so each reads as its own event.
public enum SegmentKind: String, Hashable, Sendable, Codable {
    /// A decimal digit inside a numeric word.
    case digit
    /// Anything else inside a numeric word: a group separator, a decimal
    /// separator, a sign, a currency symbol, a bracket.
    case symbol
}

/// One indivisible piece of a value.
///
/// A segment is a word, a grapheme cluster, a single character of a number, a
/// space or a line break. The morph is expressed entirely in terms of segments:
/// the diff decides which ones survive a change of value, and the plan decides
/// where each one travels.
///
/// `id` is the identity that makes a morph possible, and it is not an index. It
/// is derived from the segment's own text where it can be, so that the same
/// word keeps the same identity across a re-segmentation, and it is unique
/// across the whole value, because two segments sharing an identity would fight
/// over one place on screen.
public struct Segment: Hashable, Sendable {
    /// What this segment is, across values. Unique within a value.
    public let id: String

    /// The text this segment draws. A space is `U+00A0`, a line break is `"\n"`.
    public let string: String

    /// Absent for ordinary text; set for every character of a numeric word.
    public let kind: SegmentKind?

    /// Creates a segment.
    public init(id: String, string: String, kind: SegmentKind? = nil) {
        self.id = id
        self.string = string
        self.kind = kind
    }
}

public extension Segment {
    /// The identity upstream gives the zero-width stand-in it keeps in the flow
    /// while a value empties out, so the line box does not collapse mid-exit.
    static let emptyID = "empty"

    /// Whether this segment is a line break rather than something drawn.
    var isNewline: Bool { string == "\n" }

    /// Whether this segment is the space upstream normalises to `U+00A0`.
    ///
    /// Only this exact segment separates words. A run of two or more spaces
    /// stays one segment holding ordinary spaces, and so does not separate,
    /// which is upstream behaviour the port keeps deliberately.
    var isWordSeparator: Bool { string == "\u{00A0}" }
}
