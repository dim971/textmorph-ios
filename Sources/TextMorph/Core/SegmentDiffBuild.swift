// A port of torph's packages/torph/src/lib/text-morph/utils/diff.ts.
//
// Building the new segmentation from the plans.

import Foundation

// MARK: - building the new segmentation

extension SegmentDiff {
    static func build(
        plans: [WordPlan],
        scan: WordScan,
        oldWords: [(word: String, segments: [Segment])],
        locale: Locale,
        options: DiffOptions,
        minter: MintedIds
    ) -> DiffResult {
        var builder = Builder(
            oldWords: oldWords,
            numbersOn: options.numbers,
            // Meaningless once a value holds several figures: there is no
            // telling which of them the caret is in.
            cursorIndex: plans.count(where: \.isNumber) == 1 ? options.cursorIndex : nil,
            decimalCharacter: NumberRules.decimalSeparator(for: locale),
            minter: minter
        )

        // Reserved up front: an identity inherited later would otherwise be
        // handed to an earlier segment that only wanted its text.
        builder.reserveInheritedIds(plans: plans)

        for newIndex in scan.words.indices {
            // Includes the edges: a fresh segmentation keeps leading and
            // trailing whitespace, so the diff has to as well.
            builder.pushSeparators(scan.separatorsBefore[newIndex])
            builder.pushWord(scan.words[newIndex], plan: plans[newIndex])
        }

        builder.pushSeparators(scan.trailing)

        return builder.result
    }
}

/// Assembles the new segmentation, one word at a time.
///
/// A type rather than a long function with nested closures, because the walk
/// carries four pieces of state that every step touches: the segments so far,
/// the running offset the separator identities are derived from, the identity
/// allocator, and the splits map.
struct Builder {
    let oldWords: [(word: String, segments: [Segment])]
    let numbersOn: Bool
    /// Already narrowed to nil unless the value holds exactly one number.
    let cursorIndex: UTF16Offset?
    let decimalCharacter: Character
    let minter: MintedIds

    init(
        oldWords: [(word: String, segments: [Segment])],
        numbersOn: Bool,
        cursorIndex: UTF16Offset?,
        decimalCharacter: Character,
        minter: MintedIds
    ) {
        self.oldWords = oldWords
        self.numbersOn = numbersOn
        self.cursorIndex = cursorIndex
        self.decimalCharacter = decimalCharacter
        self.minter = minter
    }

    private var segments: [Segment] = []
    private var allocator = IdAllocator()
    private var splits: [String: [Segment]] = [:]
    /// Indexes the new value, in UTF-16 code units, and is what a separator's
    /// identity is derived from.
    private var charOffset = UTF16Offset(0)

    var result: DiffResult { DiffResult(segments: segments, splits: splits) }

    mutating func reserveInheritedIds(plans: [SegmentDiff.WordPlan]) {
        for plan in plans {
            let oldIndex: Int
            let willSplit: Bool
            switch plan {
            case .fresh: continue
            case let .reuse(index): oldIndex = index; willSplit = false
            case let .morph(index): oldIndex = index; willSplit = true
            case let .number(index): oldIndex = index; willSplit = true
            }

            let oldWord = oldWords[oldIndex]
            if willSplit, oldWord.segments.count == 1 {
                // About to be cut into per-character spans.
                let identity = oldWord.segments[0].id
                for position in 0 ..< oldWord.word.graphemes.count {
                    allocator.reserve("\(identity):\(position)")
                }
            } else {
                for segment in oldWord.segments {
                    allocator.reserve(segment.id)
                }
            }
        }
    }

    /// One separator per element, each taking its identity from where it sits
    /// in the new value.
    mutating func pushSeparators(_ separators: [Character]) {
        for separator in separators {
            if separator == "\n" {
                segments.append(Segment(
                    id: allocator.take("newline-\(charOffset)"), string: "\n"
                ))
            } else {
                segments.append(Segment(
                    id: allocator.take("space-\(charOffset)"), string: "\u{00A0}"
                ))
            }
            charOffset += 1
        }
    }

    /// One word, by whichever of the four routes its plan chose.
    mutating func pushWord(_ newWord: String, plan: SegmentDiff.WordPlan) {
        switch plan {
        case let .reuse(oldIndex):
            segments.append(contentsOf: oldWords[oldIndex].segments)

        case let .number(oldIndex):
            let previous = asNumberSegments(splitIfWhole(oldWords[oldIndex]))
            // The caret indexes the whole value; segmentNumber wants it
            // relative to the number it is inside.
            let wordCursor = cursorIndex.map { UTF16Offset($0.value - charOffset.value) }
            segments.append(contentsOf: NumberSegmenter.segmentNumber(
                newWord,
                previous: previous,
                cursor: wordCursor,
                decimalCharacter: decimalCharacter,
                minter: minter
            ).map(\.segment))

        case let .morph(oldIndex):
            segments.append(contentsOf: morphWord(newWord, from: oldWords[oldIndex]))

        case .fresh:
            if numbersOn, NumberRules.isNumericWord(newWord) {
                segments.append(contentsOf: NumberSegmenter
                    .segmentNumber(newWord, minter: minter)
                    .map(\.segment))
            } else {
                segments.append(Segment(id: allocator.take(newWord), string: newWord))
            }
        }

        charOffset += newWord.utf16Length.value
    }

    /// Per-character segments of an old word, cutting it up first if it is
    /// still a single span.
    ///
    /// Cutting a one-character word would mint a new identity for a character
    /// that never moved, so it is left alone.
    private mutating func splitIfWhole(
        _ oldWord: (word: String, segments: [Segment])
    ) -> [Segment] {
        let characters = oldWord.word.graphemes
        guard oldWord.segments.count == 1, characters.count > 1 else {
            return oldWord.segments
        }

        let identity = oldWord.segments[0].id
        let characterSegments = characters.enumerated().map { position, character in
            Segment(id: "\(identity):\(position)", string: character)
        }
        splits[identity] = characterSegments
        return characterSegments
    }

    /// A word becoming another word: its characters pair by subsequence, and
    /// the ones that pair keep their identity.
    private mutating func morphWord(
        _ newWord: String,
        from oldWord: (word: String, segments: [Segment])
    ) -> [Segment] {
        let oldCharacterSegments = splitIfWhole(oldWord)

        let oldCharacters = oldWord.word.graphemes
        let newCharacters = newWord.graphemes
        let (oldLcs, newLcs) = lcsIndices(oldCharacters, newCharacters)

        // Upstream indexes the per-character subsequence result into the
        // per-segment array, which are not the same length when the old word
        // was already several segments, as "km/h" is. It guards the result
        // rather than the index, so a pairing simply does not happen. Indexing
        // out of range would trap here, so the guard is explicit.
        var newCharacterToOldSegment: [Int: Segment] = [:]
        for position in 0 ..< newLcs.count {
            let oldPosition = oldLcs[position]
            guard oldPosition < oldCharacterSegments.count else { continue }
            newCharacterToOldSegment[newLcs[position]] = oldCharacterSegments[oldPosition]
        }

        var out: [Segment] = []
        out.reserveCapacity(newCharacters.count)
        for (position, character) in newCharacters.enumerated() {
            if let inherited = newCharacterToOldSegment[position] {
                out.append(Segment(id: inherited.id, string: String(character)))
            } else {
                out.append(Segment(
                    id: allocator.take("\(newWord)~\(position)"), string: String(character)
                ))
            }
        }
        return out
    }

    /// Fills in the kinds an older, non-numeric segmentation of the same word
    /// lacked.
    private func asNumberSegments(_ segments: [Segment]) -> [NumberSegment] {
        segments.map { segment in
            NumberSegment(
                id: segment.id,
                string: segment.string,
                kind: segment.kind ?? NumberRules.classifyKind(text: segment.string)
            )
        }
    }
}
