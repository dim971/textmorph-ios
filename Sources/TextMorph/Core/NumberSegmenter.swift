// A port of the alignment half of torph's
// packages/torph/src/lib/text-morph/utils/number.ts.

/// A segment of a numeric word, which always carries a kind.
struct NumberSegment {
    let id: String
    let string: String
    let kind: SegmentKind

    /// The segment as the rest of the engine sees it.
    var segment: Segment { Segment(id: id, string: string, kind: kind) }
}

/// Cutting a numeric word into per-character segments, and deciding which
/// character of the old value each character of the new one continues.
enum NumberSegmenter {
    /// Past this many digits of difference the columns overlap into a smear and
    /// nothing should carry across. Three is where upstream's corpus divides:
    /// the cases that need their slide sit at nought or one, the ones that read
    /// better as a replacement at three or more.
    static let magnitudeJump = 3

    /// Per-character segments for a numeric word.
    ///
    /// With no previous segmentation to carry from, every character gets a
    /// minted identity. With one, characters are paired either by caret, when
    /// `cursor` is given and the value holds a single number, or by place
    /// value, which is the default and the interesting case: a digit's identity
    /// is its column, not its position in the string.
    static func segmentNumber(
        _ value: String,
        previous: [NumberSegment]? = nil,
        cursor: UTF16Offset? = nil,
        decimalCharacter: Character = ".",
        minter: MintedIds
    ) -> [NumberSegment] {
        let characters = Array(value)

        guard let previous, !previous.isEmpty else {
            return characters.map {
                NumberSegment(
                    id: minter.take(avoiding: []),
                    string: display($0),
                    kind: NumberRules.classifyKind($0)
                )
            }
        }

        // Upstream reads a normalised space back as an ordinary one, so the two
        // compare equal. It does not do the reverse, so a value whose group
        // separator really is U+00A0 never matches a stored one. That asymmetry
        // is upstream's, and the fixtures pin it.
        let oldCharacters: [Character] = previous.map {
            $0.string == "\u{00A0}" ? " " : Character($0.string)
        }

        let matches: [Int: Int] = if let cursor {
            cursorMatch(
                oldCharacters,
                characters,
                cursor: cursor.value,
                decimalCharacter: decimalCharacter
            )
        } else {
            placeMatch(oldCharacters, characters, decimalCharacter: decimalCharacter)
        }

        var used = Set(matches.values.map { previous[$0].id })
        var result: [NumberSegment] = []
        result.reserveCapacity(characters.count)

        for (index, character) in characters.enumerated() {
            let kind = NumberRules.classifyKind(character)
            if let oldIndex = matches[index] {
                result.append(NumberSegment(
                    id: previous[oldIndex].id, string: display(character), kind: kind
                ))
            } else {
                let id = minter.take(avoiding: used)
                used.insert(id)
                result.append(NumberSegment(id: id, string: display(character), kind: kind))
            }
        }

        return result
    }

    /// A space inside a number is stored normalised, so it keeps its width and
    /// never becomes a word separator by accident.
    private static func display(_ character: Character) -> String {
        character == " " ? "\u{00A0}" : String(character)
    }
}
