# Getting started

## Install

```swift
.package(url: "https://github.com/dim971/textmorph-ios", from: "0.1.0")
```

```swift
import TextMorph
```

No dependencies. iOS 17 and macOS 14 upwards.

## Your first morph

```swift
struct Balance: View {
    @State private var total = 1204.0

    var body: some View {
        TextMorph(total, options: TextMorphOptions(decimals: 2))
            .textMorphFont(.system(size: 40, weight: .semibold))
    }
}
```

Change `total` and the digits that survive the change roll to their new place.
1,204 becoming 1,318 rolls the hundreds and the tens and leaves the thousands
alone, because a digit's identity is its column rather than its position in the
string.

## Saying what it looks like

A morph shapes its own text, so it needs a font it can measure. SwiftUI's
`Font` is not one: it can be handed to a `Text` and to nothing else. So the
font is described rather than inherited, and `.font(_:)` has no effect on a
morph:

```swift
TextMorph(status)
    .textMorphFont(.textStyle(.title))          // scales with Dynamic Type
    .textMorphColour(.secondary)
```

`.foregroundStyle(_:)` has no effect either, for the same reason: it is not
something a view can read back out of the environment.

Without either, a morph draws at the body text style in `.primary`.

## Lining it up with other text

A morph publishes its first baseline, so it sits on the same line as a `Text`
beside it:

```swift
HStack(alignment: .firstTextBaseline, spacing: 4) {
    Text("Total")
        .foregroundStyle(.secondary)
    TextMorph(total, options: TextMorphOptions(decimals: 2))
}
```

Its box is not the same shape as a `Text`'s. SwiftUI gives a `Text` its own
line box by a rule of its own; a morph uses the font's own metrics. Align on
baselines, not on frames.

## A value that is not a number

```swift
TextMorph(status)
```

A value holding a space or a line break is cut into words, so the words that
survive a change move and the rest arrive and leave. A value without one is cut
into grapheme clusters and morphs letter by letter, which is what a code, a
label or a price wants.

## A field being typed into

Pass the caret, and both sides of the edit hold their identity:

```swift
@State private var entry = ""
@State private var caret: Int?

TextMorph(Double(entry) ?? 0, cursorIndex: caret)

TextField("Amount", text: $entry)
    .onChange(of: entry) { _, new in caret = new.count }
```

Without a caret the digits realign by column, which is the right answer for a
magnitude and the wrong one for a field: carrying 123 to 1,234 is a
two-character delta of which the reader typed one, and the two are not
adjacent.

## Motion

```swift
TextMorph(value, options: TextMorphOptions(duration: 600))

TextMorph(value, options: TextMorphOptions(
    ease: .spring(stiffness: 150, damping: 19, mass: 1.2)
))
```

A spring settles on its own physics and ignores `duration`.

## When it should not move

```swift
TextMorph(value, options: TextMorphOptions(disabled: true))
```

The system's reduce-motion setting does the same thing on its own, unless
`respectReducedMotion` is turned off. In either case the value arrives already
in place and no callback fires: the morph did not fail, it was switched off.

## Where to go next

- [api.md](api.md) for every option.
- [numbers.md](numbers.md) for how a quantity rolls, and what counts as one.
- [architecture.md](architecture.md) for how a value reaches the screen.
- [fidelity.md](fidelity.md) for how this is held to the original.
