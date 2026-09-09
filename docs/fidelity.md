# Fidelity

This library claims to be a port. That is a claim about behaviour, and it is
checked rather than asserted.

## How it is checked

`Tools/gen-goldens.mjs` drives the published `torph@0.1.3` and records what it
does. The tests replay it through the Swift engine and compare. 8770 cases in
all:

| Section | Cases | Compared |
| --- | --- | --- |
| UAX #29 conformance, grapheme and word | 2710 | exactly |
| Number formatting, 25 values against 6 fraction lengths against 31 locales | 4650 | exactly |
| The diff, every ordered pair of a 22-value corpus, numbers on and off | 976 | exactly |
| Segmentation | 100 | exactly, except four recorded as diverging |
| Numeric words, decimal separators, place and caret alignment | 173 | exactly |
| Bezier samples, slopes, carried curves | 53 | exactly |
| FLIP anchors and replaced runs | 91 | exactly |
| The spring | 17 | the duration exactly, the position to within an ulp |

The Unicode conformance section is not a fixture of upstream at all: it is the
standard's own test suite. If one of those fails, the rules are wrong
independently of anything torph does.

## Regenerating

```sh
cd Tools && npm install --no-save torph@0.1.3 && cd ..
node Tools/gen-goldens.mjs Tests/TextMorphTests/Fixtures/goldens.json
node Tools/gen-unicode-tables.mjs \
  --swift Sources/TextMorph/Core/UnicodeBreakTables.swift \
  --tests Tests/TextMorphTests/Fixtures/unicode-break-tests.json
```

**If a golden fails, the port has drifted.** Find out why. Do not widen
anything, and do not regenerate to make a failure go away. Regenerating is only
correct when deliberately tracking a new upstream version, and the diff has to
be explainable.

## The one tolerance

The spring's *position* is compared to within the ulp of one. `exp`, `cos` and
`sin` go through Darwin's libm where V8 goes through fdlibm, and 4 of the 357
sampled positions differ in the last bit. Swift has no `StrictMath`, so
matching fdlibm exactly would mean porting it, which is out of proportion to a
difference no pixel can show. The bound is tied to one rather than to the value
because every branch of the position function computes `1 - something`.

The spring's *duration* has no tolerance at all, and that is the important
half. Every opacity window in the library is a fraction of it, and it is an
integer produced by a threshold crossing inside an accumulating loop, so a
last-bit difference could in principle move it by a millisecond and shift every
fade. Across the whole parameter matrix, including the near-critical damping
ratios and a precision sweep, it does not move. That is a measurement, not a
guarantee, which is why the matrix is as wide as it is.

Nothing else anywhere has a tolerance.

## Deliberate deviations

Four, all forced or fixed, all recorded in the fixtures rather than only in a
comment.

**Minted numeric identities.** Upstream mints them from a module-global counter,
which Swift 6 strict concurrency will not allow and which is not reproducible
even in JavaScript, since the counter climbs for the life of the process. Here
it is an object the view's engine owns. Upstream only requires uniqueness
against the identities already in play, so the behaviour is the same. The
fixtures canonicalise any identity beginning with U+0000 to `#0`, `#1` and so
on, in order of first appearance.

**Character splitting.** Upstream uses `String.prototype.split("")`, which cuts
on UTF-16 code units and so halves an astral character into two surrogates.
Swift cannot hold an unpaired surrogate. This port splits on extended grapheme
clusters, which changes identities and the character diff only for words
holding an astral character. Everything else stays on UTF-16 offsets, including
`space-{index}`, `newline-{offset}`, the character walk in the diff and the
public `cursorIndex`.

**Critical damping.** At a damping ratio of exactly one, upstream's overdamped
branch makes its two roots equal, divides by their difference, and returns NaN
for every time; and because `NaN > precision` is false, the settling search
then concludes the spring settled before it started and reports a duration of
minus zero. So `damping: 20` at the default stiffness and mass, an ordinary
thing to ask for, animates nothing at all. The port adds the analytic critical
branch. The fixture records upstream's answer for the record and the test
checks the fixed branch is monotonic, finite and settles. Deviating identically
on both platforms is the requirement; following upstream would ship the same
broken option twice.

**Word segmentation for dictionary languages.** The UAX #29 rules here do not
do dictionary breaking, so a run of CJK letters in a value that holds a space
elsewhere stays one word where ICU cuts it into lexical words. Four fixture
cases record it, and a test asserts they still diverge, so the day one of them
starts agreeing is a test result rather than a surprise.

## Two upstream quirks reproduced rather than tidied

Neither is a bug exactly, and both decide what moves.

The character subsequence inside a morphing word is computed over the old
word's characters but indexed into the old word's *segments*, and those are not
the same length when the word was already several segments, as `3.5 km/h` is.
Upstream checks the result instead of the index, so a pairing quietly does not
happen. Indexing out of range would trap in Swift, so the check is explicit.

A segment's kind is decided by calling a single-character digit test on a
string, and JavaScript compares strings lexicographically rather than refusing:
`"12"` reads as a digit because `"1"` sorts between `"0"` and `"9"`, `"0x1f"`
does too, and `"9x"` does not because it sorts after `"9"`. Reproduced with the
rule spelled out.

## What the fixtures cannot check

`MorphPlan` has no upstream counterpart: upstream writes keyframes and lets the
browser interpolate them. So the plan is checked against the timing table in
`MorphTiming`, which carries upstream's own numbers under upstream's own names,
and against properties: that sampling is total, that everything lands exactly
at rest, that opacity runs on linear time even where the curve does not.

The rendering is checked against itself. A value drawn one glyph run per segment
is identical, pixel for pixel, to the same line drawn in one call, at five
sizes. That claim did not hold at first, and the failure is why the test exists:
a shaper reports a glyph's position within the line it shaped, so drawing a
segment from the segment's own x counted the offset twice and everything after
the first word went off the end of the canvas. Three tests that only checked
something had been drawn all passed while that was true.

## Cross-platform

The Android twin replays the same `goldens.json` and
`unicode-break-tests.json`, byte for byte, and runs the same generators. CI on
both sides compares the digests, so a divergence is a red build rather than a
discovery months later.
