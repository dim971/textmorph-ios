# API

One view, two utilities, and a set of options. Upstream has one component and
this has one view for the same reason: the thirty-three entries on its examples
page are demos built with it, not parts of it.

## TextMorph

```swift
TextMorph(_ text: String, options:, cursorIndex:, callbacks:)
TextMorph(_ number: Double, options:, cursorIndex:, callbacks:)
TextMorph(_ value: MorphValue, options:, cursorIndex:, callbacks:)
```

A number is kept as a number rather than formatted by the caller, because the
formatting is part of the morph: the locale decides the decimal separator, and
the decimal separator is the pivot every digit alignment is measured from.

## Options

| Option | Default | What it does |
| --- | --- | --- |
| `duration` | `400` | How long a morph takes, in milliseconds. Ignored when `ease` is a spring. |
| `ease` | `.default` | `.bezier(_:)` or `.spring(stiffness:damping:mass:precision:)`. The default is a long ease out, so most of a morph happens in its first quarter. |
| `scale` | `true` | Whether a leaving segment shrinks as it goes. Only affects what leaves; an arriving segment scales either way. |
| `numbers` | `true` | Whether a numeric word morphs by place value. Off falls back to the character morph, which is what a version number wants. |
| `decimals` | `nil` | Fraction digits for a numeric value, setting both the minimum and the maximum, so `2` pads as well as truncates. `nil` means at least none and at most three, which is Intl's own default. |
| `locale` | `en` | Decides the decimal separator and how a numeric value is formatted. Deliberately not the device's: taking it from there would make the same value morph differently on two phones. |
| `debug` | `false` | Outlines every segment: blue for one that stays, green for one arriving, red for one leaving. |
| `disabled` | `false` | The value arrives already in place. |
| `respectReducedMotion` | `true` | Whether the system's reduce-motion setting does the same. |

## Callbacks

```swift
TextMorph(value, callbacks: MorphCallbacks(
    onStart: { ... },
    onComplete: { ... },
    onCancel: { ... }
))
```

`onStart` never fires for the first value a view shows, and never for an update
whose formatted value equals the one already on screen.

**Exactly one of `onComplete` and `onCancel` runs per morph.** That is
enforced by a single-shot token rather than by care. A morph replaced before it
finished is cancelled and never completed. Switching the morphing off fires
neither: the morph did not fail.

The callbacks are deliberately not part of `TextMorphOptions`, so a view that
passes a fresh closure on every update does not restart a morph in flight.

## Modifiers

```swift
.textMorphFont(_ font: TextMorphFont)
.textMorphColour(_ colour: Color)
```

Both exist because their SwiftUI counterparts cannot be used: `Font` cannot be
measured, and `.foregroundStyle` cannot be read back out of the environment.
`.font(_:)` and `.foregroundStyle(_:)` have no effect on a morph.

```swift
TextMorphFont.textStyle(.title)                 // scales with Dynamic Type
TextMorphFont.system(size: 40, weight: .semibold, design: .rounded)
TextMorphFont.custom("Inter", size: 28)
```

A named face that cannot be found falls back to the system face, and `debug`
says so.

`.multilineTextAlignment(_:)` is honoured, and is what decides which edge the
lines of a multi-line value line up on.

## Utilities

```swift
TextSegmenter.segmentText(_ value: String, locale:, numbers:) -> [Segment]
SegmentDiff.diffSegments(_ old: [Segment], _ new: String, locale:, options:) -> DiffResult
```

Upstream exports these and so does this. They are the engine with the drawing
taken away: `segmentText` cuts a value into the pieces a morph is expressed in,
and `diffSegments` says which of them survive a change of value.

Identities are only comparable between calls that share a minter, which the
standalone overloads do not. Pass values through one `TextMorph` if you need
them to line up.

## What it is not

A morph draws its own glyphs, so **the value cannot be selected**, in any mode.
It is meant for values a reader watches change: counters, prices, labels,
statuses. Body copy wants `Text`.

Right-to-left values render and morph correctly. Mixed-direction values render
correctly and morph approximately: a segment is a contiguous logical range, and
under bidi its visual extent can be split, so the perceived motion does not
always read as sensible movement. Per-character morphing of a joining script is
a non-goal.
