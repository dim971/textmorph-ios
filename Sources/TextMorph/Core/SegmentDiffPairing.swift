// A port of torph's packages/torph/src/lib/text-morph/utils/diff.ts.
//
// Deciding which old word each new word continues, and what that makes of it.

// MARK: - pairing the words

extension SegmentDiff {
    /// Which old word each new word continues.
    ///
    /// Two maps, not one, because the distinction decides what happens to the
    /// word. A word the subsequence or the reordering pass paired is the *same*
    /// word, so it keeps its segments whole. A word the similarity pass paired
    /// is a *different* word that resembles it, so it is cut into characters
    /// and they pair among themselves.
    struct Pairing {
        /// Paired by the subsequence, or by the reordering pass: the same word.
        let sameWord: [Int: Int]
        /// Paired by similarity: a different word, near enough to morph from.
        let similarWord: [Int: Int]
    }

    /// Three passes, in this order, each only looking at what the one before it
    /// left unpaired.
    static func pairWords(
        oldWordStrings: [String], newWordStrings: [String], numbersOn: Bool
    ) -> Pairing {
        // Numbers share too few characters to pair with each other, so they all
        // wear the same token while the words are being aligned.
        let tokenise = { (word: String) in
            numbersOn && NumberRules.isNumericWord(word) ? numberToken : word
        }
        let oldTokens = oldWordStrings.map(tokenise)
        let newTokens = newWordStrings.map(tokenise)

        // Pass one: the words that stayed in order.
        let (oldLcs, newLcs) = lcsIndices(oldTokens, newTokens)
        let oldMatched = Set(oldLcs)
        let newMatched = Set(newLcs)

        var sameWord: [Int: Int] = [:]
        for position in 0 ..< newLcs.count {
            sameWord[newLcs[position]] = oldLcs[position]
        }

        var oldUnmatched = oldWordStrings.indices.filter { !oldMatched.contains($0) }
        var newUnmatched = newWordStrings.indices.filter { !newMatched.contains($0) }

        // Pass two: the words that moved.
        let reordered = pairReordered(
            oldTokens: oldTokens, newTokens: newTokens,
            oldUnmatched: oldUnmatched, newUnmatched: newUnmatched
        )
        if !reordered.isEmpty {
            // Into the same map as the subsequence pairs, so a word that moved
            // keeps its segments whole rather than being cut into characters
            // that then travel separately.
            for (newIndex, oldIndex) in reordered {
                sameWord[newIndex] = oldIndex
            }
            let usedOld = Set(reordered.values)
            oldUnmatched = oldUnmatched.filter { !usedOld.contains($0) }
            newUnmatched = newUnmatched.filter { sameWord[$0] == nil }
        }

        // Pass three: the words that changed into other words.
        let similarWord = pairSimilar(
            oldWordStrings: oldWordStrings, newWordStrings: newWordStrings,
            oldUnmatched: oldUnmatched, newUnmatched: newUnmatched,
            // From the subsequence alone: the reordering pass is free to move a
            // word, so its pairs anchor nothing.
            oldGaps: gapIndices(count: oldWordStrings.count, matched: oldMatched),
            newGaps: gapIndices(count: newWordStrings.count, matched: newMatched)
        )

        return Pairing(sameWord: sameWord, similarWord: similarWord)
    }

    /// Words that moved rather than changed, which a subsequence cannot capture
    /// because it only ever runs forwards. Order-preserving: the first free old
    /// word wins.
    private static func pairReordered(
        oldTokens: [String], newTokens: [String],
        oldUnmatched: [Int], newUnmatched: [Int]
    ) -> [Int: Int] {
        var pairs: [Int: Int] = [:]
        var used = Set<Int>()
        for newIndex in newUnmatched {
            for oldIndex in oldUnmatched where !used.contains(oldIndex) {
                if newTokens[newIndex] == oldTokens[oldIndex] {
                    pairs[newIndex] = oldIndex
                    used.insert(oldIndex)
                    break
                }
            }
        }
        return pairs
    }

    /// Words near enough to each other to read as one becoming the other.
    ///
    /// Skipped entirely past the pairing cap, which leaves the words to arrive
    /// and leave rather than blocking the frame on a quadratic comparison.
    private static func pairSimilar(
        oldWordStrings: [String], newWordStrings: [String],
        oldUnmatched: [Int], newUnmatched: [Int],
        oldGaps: [Int], newGaps: [Int]
    ) -> [Int: Int] {
        guard oldUnmatched.count * newUnmatched.count <= maximumMorphPairings else { return [:] }

        var pairs: [Int: Int] = [:]
        var used = Set<Int>()
        for newIndex in newUnmatched {
            var bestOld = -1
            var bestSimilarity = minimumSimilarity

            for oldIndex in oldUnmatched where !used.contains(oldIndex) {
                // A pairing that crosses a surviving word would drag its
                // characters the width of the value.
                if oldGaps[oldIndex] != newGaps[newIndex] { continue }
                let similarity = affinity(oldWordStrings[oldIndex], newWordStrings[newIndex])
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestOld = oldIndex
                }
            }

            if bestOld >= 0 {
                pairs[newIndex] = bestOld
                used.insert(bestOld)
            }
        }
        return pairs
    }

    /// How many subsequence matches sit before each word: the index of the gap
    /// it occupies. Two words in the same gap can pair without crossing a
    /// survivor.
    static func gapIndices(count: Int, matched: Set<Int>) -> [Int] {
        var gaps: [Int] = []
        gaps.reserveCapacity(count)
        var anchors = 0
        for index in 0 ..< count {
            gaps.append(anchors)
            if matched.contains(index) { anchors += 1 }
        }
        return gaps
    }

    /// An old word's claim on a new one. A matching numeric skeleton beats
    /// shared characters, so `$1,204` pairs with `$1,318` rather than with
    /// whatever it happens to have letters in common with.
    static func affinity(_ a: String, _ b: String) -> Double {
        if NumberRules.hasDigit(a) || NumberRules.hasDigit(b),
           NumberRules.numericSkeleton(a) == NumberRules.numericSkeleton(b) {
            return 1
        }
        return characterSimilarity(a, b)
    }

    static func characterSimilarity(_ a: String, _ b: String) -> Double {
        if a.isEmpty || b.isEmpty { return 0 }
        let (matched, _) = lcsIndices(Array(a), Array(b))
        return Double(matched.count) / Double(max(a.count, b.count))
    }
}

// MARK: - deciding what each word becomes

extension SegmentDiff {
    /// How a new word gets its segments. The identity reservation pass and the
    /// build loop have to agree, so the decision is made once, up front.
    enum WordPlan {
        /// Nothing to carry from.
        case fresh
        /// The old word's segments, unchanged.
        case reuse(Int)
        /// The old word's characters, matched by subsequence.
        case morph(Int)
        /// The old number's characters, matched by place value or by caret.
        case number(Int)

        /// Whether this word will morph by place value. The caret only means
        /// something when exactly one word in the value does.
        var isNumber: Bool {
            if case .number = self { return true }
            return false
        }
    }

    static func plan(
        newWordStrings: [String], pairing: Pairing, numbersOn: Bool
    ) -> [WordPlan] {
        // Keyed on what the word is becoming, not on what it was.
        newWordStrings.enumerated().map { newIndex, newWord in
            let same = pairing.sameWord[newIndex]
            guard let oldIndex = same ?? pairing.similarWord[newIndex] else { return .fresh }
            if numbersOn, NumberRules.isNumericWord(newWord) { return .number(oldIndex) }
            return same != nil ? .reuse(oldIndex) : .morph(oldIndex)
        }
    }
}
