// A port of torph's packages/torph/src/lib/text-morph/utils/diff.ts.

import Foundation

/// What a change of value does to the segments already on screen.
public struct DiffResult {
    /// The new value's segments. One carrying an identity that appears in the
    /// old segmentation survives the change and moves; one carrying a fresh
    /// identity arrives; an old identity absent from here leaves.
    public let segments: [Segment]

    /// Old segments that were cut finer to make the match.
    ///
    /// A word that survived as a single span has to be split into per-character
    /// spans before any of its characters can move independently. The key is
    /// the identity of the span that was split, and the value is what it became.
    public let splits: [String: [Segment]]
}

/// How to match a new value against the segments already on screen.
public struct DiffOptions {
    /// Numeric words morph by place value. Off falls back to a character diff.
    public var numbers: Bool

    /// The caret, honoured only when the value holds a single number.
    public var cursorIndex: UTF16Offset?

    /// Creates options.
    public init(numbers: Bool = true, cursorIndex: UTF16Offset? = nil) {
        self.numbers = numbers
        self.cursorIndex = cursorIndex
    }
}

/// Matching a new value against the segments already on screen.
public enum SegmentDiff {
    /// Numbers share too few characters to pair with each other, so for the
    /// purposes of aligning words they all collapse to one token. A NULL cannot
    /// occur in a value, so the token cannot collide with a real word.
    static let numberToken = "\u{0000}#"

    /// Below this share of characters in common, two words are not the same
    /// word wearing a change. It is also what keeps a number off a real word,
    /// since the two pair freely otherwise.
    static let minimumSimilarity = 0.4

    /// The diff runs before the first frame, so past these it degrades to a
    /// fresh segmentation rather than blocking.
    static let maximumMorphPairings = 2500
    static let maximumLcsCells = 1_000_000

    /// Matches a new value against an existing segmentation.
    public static func diffSegments(
        _ oldSegments: [Segment],
        _ newText: String,
        locale: Locale = defaultMorphLocale,
        options: DiffOptions = DiffOptions()
    ) -> DiffResult {
        diffSegments(oldSegments, newText, locale: locale, options: options, minter: MintedIds())
    }

    static func diffSegments(
        _ oldSegments: [Segment],
        _ newText: String,
        locale: Locale,
        options: DiffOptions,
        minter: MintedIds
    ) -> DiffResult {
        let numbersOn = options.numbers
        let oldWords = TextSegmenter.groupIntoWords(oldSegments)

        // Text identities are derived from the text and survive a
        // re-segmentation; minted numeric ones do not, so a value with digits
        // anywhere cannot take the fast path.
        let digitsInvolved = numbersOn
            && (NumberRules.hasDigit(newText) || oldWords.contains { NumberRules.hasDigit($0.word) })
        let newHasSpaces = newText.contains(" ")
        let newHasNewlines = newText.contains("\n")

        if oldWords.count <= 1, !newHasSpaces, !newHasNewlines, !digitsInvolved {
            return DiffResult(
                segments: TextSegmenter.segmentText(
                    newText, locale: locale, numbers: numbersOn, minter: minter
                ),
                splits: [:]
            )
        }

        let scan = scanWords(newText)
        let oldWordStrings = oldWords.map(\.word)

        if oldWordStrings.count * scan.words.count > maximumLcsCells {
            return DiffResult(
                segments: TextSegmenter.segmentText(
                    newText, locale: locale, numbers: numbersOn, minter: minter
                ),
                splits: [:]
            )
        }

        let pairing = pairWords(
            oldWordStrings: oldWordStrings, newWordStrings: scan.words, numbersOn: numbersOn
        )
        let plans = plan(
            newWordStrings: scan.words, pairing: pairing, numbersOn: numbersOn
        )

        return build(
            plans: plans,
            scan: scan,
            oldWords: oldWords,
            locale: locale,
            options: options,
            minter: minter
        )
    }
}

// MARK: - reading the new value

extension SegmentDiff {
    /// The new value's words, and the separators that precede each of them.
    ///
    /// This replaces upstream's `split(/( |\n)/)`. Splitting on a capturing
    /// group does not mean the same thing in Swift, and the sequence of empty
    /// parts it yields between two separators is load bearing only in that
    /// upstream skips them, so the walk is written out.
    struct WordScan {
        let words: [String]
        /// The separators immediately before each word, in order.
        let separatorsBefore: [[Character]]
        /// The separators after the last word, which have no word to attach to.
        let trailing: [Character]
    }

    static func scanWords(_ newText: String) -> WordScan {
        var words: [String] = []
        var separatorsBefore: [[Character]] = []
        var pending: [Character] = []
        var current = ""

        for character in newText {
            if character == " " || character == "\n" {
                if !current.isEmpty {
                    separatorsBefore.append(pending)
                    words.append(current)
                    current = ""
                    pending = []
                }
                pending.append(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            separatorsBefore.append(pending)
            words.append(current)
            pending = []
        }

        return WordScan(words: words, separatorsBefore: separatorsBefore, trailing: pending)
    }
}
