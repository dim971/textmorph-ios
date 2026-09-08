// Property lookup over the generated tables.
//
// Each table is a flat, sorted, non-overlapping list of ranges: start, end and
// value for a table with values, start and end for a boolean one. A flat array
// of integers rather than an array of tuples is deliberate: it compiles fast at
// this size, and a binary search over a stride is as cheap as the lookup gets
// without a two-stage trie, which this library's values are far too short to
// need.

extension UnicodeBreakTables {
    /// Grapheme_Cluster_Break for a scalar. Anything unlisted is Other.
    static func graphemeProperty(_ scalar: Unicode.Scalar) -> GraphemeBreakProperty {
        let raw = value(in: grapheme, for: scalar.value)
        return GraphemeBreakProperty(rawValue: raw) ?? .other
    }

    /// Word_Break for a scalar. Anything unlisted is Other.
    static func wordProperty(_ scalar: Unicode.Scalar) -> WordBreakProperty {
        let raw = value(in: word, for: scalar.value)
        return WordBreakProperty(rawValue: raw) ?? .other
    }

    /// Indic_Conjunct_Break for a scalar. Anything unlisted is None.
    static func indicConjunctBreakProperty(_ scalar: Unicode.Scalar) -> IndicConjunctBreak {
        let raw = value(in: indicConjunctBreak, for: scalar.value)
        return IndicConjunctBreak(rawValue: raw) ?? .none
    }

    /// Whether a scalar is Extended_Pictographic, which rules GB11 and WB3c need.
    static func isExtendedPictographic(_ scalar: Unicode.Scalar) -> Bool {
        contains(extendedPictographic, scalar.value)
    }

    /// The value of the range holding `codePoint`, or 0 for the table default.
    private static func value(in table: [UInt32], for codePoint: UInt32) -> UInt8 {
        guard let index = rangeIndex(in: table, stride: 3, for: codePoint) else { return 0 }
        return UInt8(truncatingIfNeeded: table[index + 2])
    }

    private static func contains(_ table: [UInt32], _ codePoint: UInt32) -> Bool {
        rangeIndex(in: table, stride: 2, for: codePoint) != nil
    }

    /// The start index of the range holding `codePoint`, or nil if unlisted.
    private static func rangeIndex(in table: [UInt32], stride: Int, for codePoint: UInt32) -> Int? {
        var low = 0
        var high = table.count / stride - 1
        while low <= high {
            let mid = (low + high) / 2
            let base = mid * stride
            if codePoint < table[base] {
                high = mid - 1
            } else if codePoint > table[base + 1] {
                low = mid + 1
            } else {
                return base
            }
        }
        return nil
    }
}
