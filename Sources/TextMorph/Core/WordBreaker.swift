// UAX #29 word boundaries.
//
// Word breaking needs more context than grapheme breaking: rules WB6, WB7b,
// WB11 and WB12 look one significant character past the boundary, and WB7,
// WB7c and WB11 look one before it. "Significant" is the catch, and it is what
// rule WB4 defines: an extend, a format character or a ZWJ following a base
// character is absorbed into that base and is invisible to every rule after
// WB4. Resolving that folding once, for the whole value, is what keeps this
// linear.

/// Decides word boundaries for one decoded value.
struct WordBreaker {
    private let scalars: [ScalarInfo]

    /// Indices of the scalars rules WB5 and later can see, in order.
    private let significant: [Int]

    /// For each scalar, its position in `significant`, or the position of the
    /// base it folded into.
    private let significantIndex: [Int]

    init(_ scalars: [ScalarInfo]) {
        self.scalars = scalars

        var significant: [Int] = []
        var significantIndex = [Int](repeating: 0, count: scalars.count)
        // A base is what an extend, format or ZWJ can attach to. A mandatory
        // break resets it: WB4 explicitly does not fold across one, so an
        // extend at the start of a value, or just after a line break, is a
        // character in its own right.
        var hasBase = false

        for (index, info) in scalars.enumerated() {
            let property = info.word
            if Self.isIgnorable(property), hasBase {
                significantIndex[index] = significant.count - 1
                continue
            }
            significantIndex[index] = significant.count
            significant.append(index)
            hasBase = !Self.isMandatoryBreak(property)
        }

        self.significant = significant
        self.significantIndex = significantIndex
    }

    /// Whether a word boundary falls immediately before `index`.
    func breaks(before index: Int) -> Bool {
        let previous = scalars[index - 1]
        let next = scalars[index]

        // WB3, WB3a and WB3b: a line break is a boundary on both sides, and CR
        // LF is one break rather than two.
        if previous.word == .cr, next.word == .lf { return false }
        if Self.isMandatoryBreak(previous.word) { return true }
        if Self.isMandatoryBreak(next.word) { return true }

        // WB3c and WB3d see raw adjacency, because they come before WB4.
        if previous.word == .zwj, next.isExtendedPictographic { return false }
        if previous.word == .wSegSpace, next.word == .wSegSpace { return false }

        // WB4: an extend, format or ZWJ attaches to whatever it follows.
        if Self.isIgnorable(next.word) { return false }

        return breaksBetweenSignificant(before: index)
    }

    // MARK: - rules WB5 to WB999, over the folded sequence

    // swiftlint:disable cyclomatic_complexity
    /// One branch per named rule of UAX #29, in the standard's own order.
    ///
    /// Splitting the chain to satisfy a complexity threshold would put a
    /// function boundary in the middle of a rule sequence, and the sequence is
    /// the thing a reader has to check against the standard.
    private func breaksBetweenSignificant(before index: Int) -> Bool {
        let position = significantIndex[index]
        let prev = property(atSignificant: position - 1)
        let next = property(atSignificant: position)
        let beforePrev = property(atSignificant: position - 2)
        let afterNext = property(atSignificant: position + 1)

        // WB5: a letter run stays together.
        if isAHLetter(prev), isAHLetter(next) { return false }
        // WB6 and WB7: one mid-word punctuation mark between two letters.
        if isAHLetter(prev), isMidLetterOrQ(next), isAHLetter(afterNext) { return false }
        if isAHLetter(beforePrev), isMidLetterOrQ(prev), isAHLetter(next) { return false }
        // WB7a, WB7b and WB7c: Hebrew quoting.
        if prev == .hebrewLetter, next == .singleQuote { return false }
        if prev == .hebrewLetter, next == .doubleQuote, afterNext == .hebrewLetter { return false }
        if beforePrev == .hebrewLetter, prev == .doubleQuote, next == .hebrewLetter { return false }
        // WB8, WB9 and WB10: digits stay with digits and with letters.
        if prev == .numeric, next == .numeric { return false }
        if isAHLetter(prev), next == .numeric { return false }
        if prev == .numeric, isAHLetter(next) { return false }
        // WB11 and WB12: one numeric separator between two digit runs.
        if beforePrev == .numeric, isMidNumOrQ(prev), next == .numeric { return false }
        if prev == .numeric, isMidNumOrQ(next), afterNext == .numeric { return false }
        // WB13: katakana stays together.
        if prev == .katakana, next == .katakana { return false }
        // WB13a and WB13b: an extender joins on either side.
        if isExtenderLeft(prev), next == .extendNumLet { return false }
        if prev == .extendNumLet, isExtenderRight(next) { return false }
        // WB15 and WB16: regional indicators pair up from the start of the run.
        if prev == .regionalIndicator, next == .regionalIndicator {
            return regionalIndicatorRun(endingBefore: position).isMultiple(of: 2)
        }
        // WB999
        return true
    }

    // swiftlint:enable cyclomatic_complexity

    /// The property at a position in the folded sequence, or Other outside it,
    /// which is what "no such character" means to every rule here.
    private func property(atSignificant position: Int) -> WordBreakProperty {
        guard position >= 0, position < significant.count else { return .other }
        return scalars[significant[position]].word
    }

    private func regionalIndicatorRun(endingBefore position: Int) -> Int {
        var count = 0
        var cursor = position - 1
        while cursor >= 0, property(atSignificant: cursor) == .regionalIndicator {
            count += 1
            cursor -= 1
        }
        return count
    }

    // MARK: - the rule macros, spelled out as UAX #29 defines them

    private static func isIgnorable(_ property: WordBreakProperty) -> Bool {
        property == .extend || property == .format || property == .zwj
    }

    private static func isMandatoryBreak(_ property: WordBreakProperty) -> Bool {
        property == .newline || property == .cr || property == .lf
    }

    /// AHLetter
    private func isAHLetter(_ property: WordBreakProperty) -> Bool {
        property == .aLetter || property == .hebrewLetter
    }

    /// MidLetter | MidNumLetQ
    private func isMidLetterOrQ(_ property: WordBreakProperty) -> Bool {
        property == .midLetter || property == .midNumLet || property == .singleQuote
    }

    /// MidNum | MidNumLetQ
    private func isMidNumOrQ(_ property: WordBreakProperty) -> Bool {
        property == .midNum || property == .midNumLet || property == .singleQuote
    }

    /// WB13a's left side: AHLetter | Numeric | Katakana | ExtendNumLet
    private func isExtenderLeft(_ property: WordBreakProperty) -> Bool {
        isExtenderRight(property) || property == .extendNumLet
    }

    /// WB13b's right side: AHLetter | Numeric | Katakana
    private func isExtenderRight(_ property: WordBreakProperty) -> Bool {
        isAHLetter(property) || property == .numeric || property == .katakana
    }
}
