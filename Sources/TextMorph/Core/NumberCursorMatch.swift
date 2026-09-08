// Caret matching, from torph's text-morph/utils/number.ts.

extension NumberSegmenter {
    /// Pairs characters around a caret, for a field being typed into.
    ///
    /// The caret says where the edit was, so both sides of it map across
    /// unchanged and only the edit itself is new. That is a better answer than
    /// place matching for a field, where the reader's attention is on the
    /// keystroke rather than on the magnitude.
    ///
    /// The walk is over everything *but* the grouping separators. A comma
    /// reflows with the magnitude rather than with the keystroke, so counting
    /// it into the edit would shear every match past the caret: carrying `123`
    /// to `1,234` is a two-character delta of which the reader typed one, and
    /// the two are not adjacent.
    static func cursorMatch(
        _ oldCharacters: [Character],
        _ newCharacters: [Character],
        cursor: Int,
        decimalCharacter: Character
    ) -> [Int: Int] {
        var matches: [Int: Int] = [:]

        let oldKept = keptIndices(oldCharacters, decimalCharacter: decimalCharacter)
        let newKept = keptIndices(newCharacters, decimalCharacter: decimalCharacter)

        func pair(_ newPosition: Int, _ oldPosition: Int) {
            matches[newKept[newPosition]] = oldKept[oldPosition]
        }

        var keptCursor = 0
        while keptCursor < newKept.count, newKept[keptCursor] < cursor {
            keptCursor += 1
        }

        let lengthDifference = newKept.count - oldKept.count
        let pairs = if lengthDifference > 0 {
            pairAfterInsertion(
                caret: keptCursor,
                arrived: lengthDifference,
                oldCount: oldKept.count,
                newCount: newKept.count
            )
        } else if lengthDifference < 0 {
            pairAfterDeletion(
                caret: keptCursor,
                left: -lengthDifference,
                oldCount: oldKept.count,
                newCount: newKept.count
            )
        } else {
            pairAfterReplacement(
                oldCharacters,
                newCharacters,
                oldKept: oldKept,
                newKept: newKept
            )
        }
        for (newPosition, oldPosition) in pairs {
            pair(newPosition, oldPosition)
        }

        // Paired from the units end, so the thousands comma stays the thousands
        // comma however the magnitude moved.
        let oldSeparators = groupingIndices(oldCharacters, decimalCharacter: decimalCharacter)
        let newSeparators = groupingIndices(newCharacters, decimalCharacter: decimalCharacter)
        var k = 1
        while k <= oldSeparators.count, k <= newSeparators.count {
            let oldIndex = oldSeparators[oldSeparators.count - k]
            let newIndex = newSeparators[newSeparators.count - k]
            if oldCharacters[oldIndex] == newCharacters[newIndex] {
                matches[newIndex] = oldIndex
            }
            k += 1
        }

        return matches
    }

    /// Characters arrived. Everything before the edit holds its place, and
    /// everything after it shifts by however many arrived.
    private static func pairAfterInsertion(
        caret: Int, arrived: Int, oldCount: Int, newCount: Int
    ) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        let editStart = caret - arrived
        for index in 0 ..< max(0, min(editStart, oldCount)) {
            pairs.append((index, index))
        }
        for index in caret ..< newCount {
            let oldIndex = index - arrived
            if oldIndex >= 0, oldIndex < oldCount { pairs.append((index, oldIndex)) }
        }
        return pairs
    }

    /// Characters left. Everything before the caret holds its place, and
    /// everything after it closes up.
    private static func pairAfterDeletion(
        caret: Int, left: Int, oldCount: Int, newCount: Int
    ) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        for index in 0 ..< min(caret, newCount) {
            pairs.append((index, index))
        }
        for index in caret ..< newCount {
            let oldIndex = index + left
            if oldIndex >= 0, oldIndex < oldCount { pairs.append((index, oldIndex)) }
        }
        return pairs
    }

    /// The same length, so a character was replaced. Only the ones that did not
    /// change carry over; the caret plays no part.
    private static func pairAfterReplacement(
        _ oldCharacters: [Character], _ newCharacters: [Character],
        oldKept: [Int], newKept: [Int]
    ) -> [(Int, Int)] {
        (0 ..< newKept.count)
            .filter { newCharacters[newKept[$0]] == oldCharacters[oldKept[$0]] }
            .map { ($0, $0) }
    }

    /// A separator that groups digits, as opposed to the one that divides the
    /// fraction off.
    static func isGrouping(_ character: Character, decimalCharacter: Character) -> Bool {
        character != decimalCharacter && NumberRules.coreSeparators.contains(character)
    }

    /// The indices the caret walk counts: everything but the grouping separators.
    static func keptIndices(_ characters: [Character], decimalCharacter: Character) -> [Int] {
        characters.indices.filter {
            !isGrouping(characters[$0], decimalCharacter: decimalCharacter)
        }
    }

    /// The indices of the grouping separators.
    static func groupingIndices(_ characters: [Character], decimalCharacter: Character) -> [Int] {
        characters.indices.filter {
            isGrouping(characters[$0], decimalCharacter: decimalCharacter)
        }
    }
}
