// Place-value matching, from torph's text-morph/utils/number.ts.

extension NumberSegmenter {
    /// Pairs characters by distance from the decimal separator, not left to
    /// right, because a digit's identity is its column.
    ///
    /// Both walks skip a mismatch rather than stopping at it, so a changed
    /// character in the middle of a number does not cost the ones past it.
    ///
    /// Returns a map from an index in the new value to the index in the old
    /// value it continues.
    static func placeMatch(
        _ oldCharacters: [Character],
        _ newCharacters: [Character],
        decimalCharacter: Character
    ) -> [Int: Int] {
        let trimmed = trimAffixes(oldCharacters, newCharacters)
        let matches = trimmed.matches
        let start = trimmed.start
        let oldEnd = trimmed.oldEnd
        let newEnd = trimmed.newEnd

        let oldPivot = findPivot(
            oldCharacters,
            from: start,
            to: oldEnd,
            decimalCharacter: decimalCharacter
        )
        let newPivot = findPivot(
            newCharacters,
            from: start,
            to: newEnd,
            decimalCharacter: decimalCharacter
        )

        let oldDigits = integerDigits(oldCharacters, from: start, to: oldPivot)
        let newDigits = integerDigits(newCharacters, from: start, to: newPivot)

        // A side with no digits is a field being typed into or emptied, not a
        // magnitude, so the jump test does not apply to it.
        if oldDigits > 0, newDigits > 0, abs(oldDigits - newDigits) >= magnitudeJump {
            return matches
        }

        var context = MatchContext(
            oldCharacters: oldCharacters, newCharacters: newCharacters, matches: matches
        )

        // A separator holds its distance from the pivot, which is what slides
        // the comma one group along on 999,999 to 1,000,000. After a reshape it
        // would have to cross the digits that carried, the two passing in
        // opposite directions, so it leaves instead.
        let reshaped = context.matchDigits(
            oldFrom: start, oldTo: oldPivot, newFrom: start, newTo: newPivot, towardsPivot: true
        )
        if !reshaped {
            var k = 1
            while oldPivot - k >= start, newPivot - k >= start {
                context.matchSeparator(oldIndex: oldPivot - k, newIndex: newPivot - k)
                k += 1
            }
        }

        // Absent from either value, the pivot is that value's end, and there is
        // no fraction to align.
        if oldPivot < oldEnd, newPivot < newEnd {
            context.matches[newPivot] = oldPivot

            var k = 1
            while oldPivot + k < oldEnd, newPivot + k < newEnd {
                context.matchSeparator(oldIndex: oldPivot + k, newIndex: newPivot + k)
                k += 1
            }
            _ = context.matchDigits(
                oldFrom: oldPivot + 1, oldTo: oldEnd,
                newFrom: newPivot + 1, newTo: newEnd, towardsPivot: false
            )
        }

        return context.matches
    }

    /// Pairs off the affixes at either end, which belong to no column, and
    /// reports the range of the magnitude that is left.
    ///
    /// A digit stops either walk: it belongs to the magnitude, and the
    /// magnitude is what columns are for.
    private static func trimAffixes(
        _ oldCharacters: [Character], _ newCharacters: [Character]
    ) -> TrimmedRange {
        var matches: [Int: Int] = [:]

        var start = 0
        while start < oldCharacters.count, start < newCharacters.count,
              oldCharacters[start] == newCharacters[start],
              !NumberRules.isDigit(oldCharacters[start]) {
            matches[start] = start
            start += 1
        }

        var oldEnd = oldCharacters.count
        var newEnd = newCharacters.count
        while oldEnd > start, newEnd > start,
              oldCharacters[oldEnd - 1] == newCharacters[newEnd - 1],
              !NumberRules.isDigit(oldCharacters[oldEnd - 1]) {
            matches[newEnd - 1] = oldEnd - 1
            oldEnd -= 1
            newEnd -= 1
        }

        return TrimmedRange(matches: matches, start: start, oldEnd: oldEnd, newEnd: newEnd)
    }

    /// The last decimal separator inside the affix-trimmed range, or the range
    /// end when the value has no fraction.
    static func findPivot(
        _ characters: [Character], from start: Int, to end: Int, decimalCharacter: Character
    ) -> Int {
        var index = end - 1
        while index >= start {
            if characters[index] == decimalCharacter { return index }
            index -= 1
        }
        return end
    }

    /// How many digits sit on the integer side of the pivot.
    static func integerDigits(_ characters: [Character], from start: Int, to pivot: Int) -> Int {
        guard start < pivot else { return 0 }
        return (start ..< pivot).count { NumberRules.isDigit(characters[$0]) }
    }

    /// The indices of the digits in a range.
    static func digitIndices(_ characters: [Character], from start: Int, to end: Int) -> [Int] {
        guard start < end else { return [] }
        return (start ..< end).filter { NumberRules.isDigit(characters[$0]) }
    }
}

/// What is left of two numbers once the affixes at either end have paired off.
private struct TrimmedRange {
    /// The affix pairings, which the column walks then add to.
    let matches: [Int: Int]
    /// The first index of the magnitude, in both values.
    let start: Int
    /// One past the magnitude's last index in the old value.
    let oldEnd: Int
    /// One past the magnitude's last index in the new value.
    let newEnd: Int
}

/// The two values and the pairing being built, so the column walks can be
/// written as the small mutating steps upstream writes them as closures.
private struct MatchContext {
    let oldCharacters: [Character]
    let newCharacters: [Character]
    var matches: [Int: Int]

    /// Pairs one separator with the one holding the same distance from the pivot.
    mutating func matchSeparator(oldIndex: Int, newIndex: Int) {
        let character = oldCharacters[oldIndex]
        if NumberRules.isDigit(character) { return }
        if character == newCharacters[newIndex] { matches[newIndex] = oldIndex }
    }

    /// Pairs the digits on one side of the pivot.
    ///
    /// By column where the count is unchanged, and by subsequence where it
    /// changed. Reshaping is integer-side only: a fraction's columns are fixed
    /// by the decimal point, so 1.5 becoming 1.25 gains a hundredths place
    /// rather than sliding the 5 along. `towardsPivot` reverses the runs before
    /// the subsequence walk so its ties resolve from the units column, which is
    /// the column a reader is watching.
    ///
    /// Returns whether any digit survived a reshape.
    mutating func matchDigits(
        oldFrom: Int, oldTo: Int, newFrom: Int, newTo: Int, towardsPivot: Bool
    ) -> Bool {
        let oldIndices = NumberSegmenter.digitIndices(oldCharacters, from: oldFrom, to: oldTo)
        let newIndices = NumberSegmenter.digitIndices(newCharacters, from: newFrom, to: newTo)

        if oldIndices.count == newIndices.count || !towardsPivot {
            for k in 0 ..< min(oldIndices.count, newIndices.count) {
                let oldIndex = oldIndices[k]
                let newIndex = newIndices[k]
                if oldCharacters[oldIndex] == newCharacters[newIndex] {
                    matches[newIndex] = oldIndex
                }
            }
            return false
        }

        let oldRun = oldIndices.map { oldCharacters[$0] }.reversed().map(\.self)
        let newRun = newIndices.map { newCharacters[$0] }.reversed().map(\.self)
        let (a, b) = lcsIndices(oldRun, newRun)

        for k in 0 ..< a.count {
            let oldIndex = oldIndices[oldIndices.count - 1 - a[k]]
            let newIndex = newIndices[newIndices.count - 1 - b[k]]
            matches[newIndex] = oldIndex
        }

        return !a.isEmpty
    }
}
