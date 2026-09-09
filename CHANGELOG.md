# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **The showcase now covers torph's examples page card for card.** Twenty demos
  that were missing, and thirteen brought in line with upstream's own values,
  intervals and eases, read out of its site sources rather than invented: the
  two pages can be scrolled side by side. Thirty-five in all, the last two
  being the first render and the empty transition, which upstream does not
  show. The interface around each morph is written for this platform rather
  than reproduced, and the catalogue says which differences are deliberate.

### Changed

- **A morphing word is cut with the ported UAX #29 grapheme rules**, not with
  Swift's `Character`. Both are extended grapheme clusters, but `Character`
  follows whichever Unicode version the running OS carries, so the same value
  could be cut one way on one device and another way on the next, and
  differently again from the Android twin, for any value holding an emoji or a
  combining mark. Identities change only for such values.
- **A quantity is decided in UTF-16 code units**, which is upstream's unit and
  the twin's. `\u{1ECB0}5`, whose prefix is an astral currency symbol, is no
  longer read as a quantity, because neither of its two code units is in general
  category Sc; and `hasDigit` now sees the digit in a digit followed by a
  combining mark, which as one `Character` it did not.

## [0.1.0]

First release. A SwiftUI port of [Torph](https://torph.lochie.me) 0.1.3.

### Added

- `TextMorph`, one view mirroring upstream's one component, with every option
  upstream takes: duration, easing as a cubic bezier or a spring, scale,
  place-value number morphing, fraction digits, locale, debug, disabled and
  reduce-motion.
- Place-value alignment for quantities, with caret matching for a field being
  typed into.
- The two utilities upstream exports, `segmentText` and `diffSegments`.
- UAX #29 grapheme and word segmentation, ported over generated tables rather
  than delegated to the platform's ICU, so the two ports cannot diverge with an
  OS version. All 766 grapheme and 1944 word cases of Unicode's own conformance
  suite pass.
- Fixtures generated from the published npm package, 8770 cases, replayed by
  the test suite. One tolerance in the whole suite, on the spring's position,
  documented in `docs/fidelity.md`.
- A showcase catalogue of fifteen demos and a playground.
- Six documents under `docs/`.

### Changed from upstream

- **Critical damping is fixed.** At a damping ratio of exactly one, upstream's
  spring divides by zero, returns NaN for every time, and then reports a
  settling duration of minus zero, so `damping: 20` at the default stiffness
  and mass animates nothing at all. This port adds the analytic critical
  branch.
- **Minted numeric identities are owned rather than global.** Upstream's
  counter is a module-global that climbs for the life of the process, which
  Swift 6 strict concurrency will not allow and which makes the same call
  return different identities depending on what ran before it. Behaviour is
  unchanged, because uniqueness is what upstream actually requires.
- **Characters are split on grapheme clusters**, not UTF-16 code units, because
  Swift cannot hold an unpaired surrogate. This changes identities only for
  words holding an astral character. Everything else stays on UTF-16 offsets.
- **Dictionary word breaking is not implemented.** A run of CJK letters in a
  value that holds a space elsewhere stays one word where ICU cuts it into
  lexical words. Upstream already segments those languages by grapheme whenever
  the value has no space, so the difference is confined to spaced CJK.
- **A morph is never selectable.** It draws its own glyphs, and the plain
  `Text` that would restore selection when nothing is moving does not land in
  the same place, so there is one rendering path rather than a visible jump.
- **U+2019 is a separator between digits, and is not upstream.** CLDR groups
  Swiss German with U+0027 in one version and U+2019 in another, and a device's
  OS decides which; without the addition, the same number would roll by place
  value on one OS version and morph character by character on the next.
- **The font and the colour are described rather than inherited.** `Font`
  cannot be measured and `.foregroundStyle` cannot be read back out of the
  environment, so `.textMorphFont(_:)` and `.textMorphColour(_:)` exist and
  `.font(_:)` has no effect.

[Unreleased]: https://github.com/dim971/textmorph-ios/compare/0.1.0...HEAD
[0.1.0]: https://github.com/dim971/textmorph-ios/releases/tag/0.1.0
