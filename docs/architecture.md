# Architecture

How a value reaches the screen, and why the pieces are where they are.

## The three layers

```
Core/      pure logic, no UI type in any signature
Engine/    text shaping, the layout cache, the clock, the state machine
Views/     the public view and the canvas
```

`Core` is a transcription of the JavaScript original and is where the fixtures
bite. `Engine` is the platform. `Views` is SwiftUI. The Android twin mirrors
`Core` file for file; only `Engine` and the platform layer differ, and only
where the platform forces it.

## One change of value, end to end

1. The value is formatted, if it is a number. An update whose formatted value
   equals the one on screen stops here, before anything, including `onStart`.
2. `SegmentDiff` matches the new value against the segments already on screen
   and says which survive, which arrive and which leave. It also says which old
   spans have to be cut finer to make the match.
3. Each line of each value is shaped once, and the boxes are computed from the
   result. Three layouts are needed: where the old segments were, where the new
   ones will settle, and where they would settle at the width the container had
   a moment ago.
4. `MorphPlanner` turns those into a `MorphPlan`: a from and a to state for
   every segment, a fade window, a scale origin, and the container's two axes.
5. `TimelineView` supplies elapsed time. `MorphPlan.frame(atElapsed:)` turns it
   into the state of every segment. `TextMorphCanvas` draws it.

## Why the clock is linear

Upstream animates a transform with the author's curve and an opacity linearly
over a fraction of the duration. If the clock itself were eased, recovering
linear time inside that fraction would need the curve's inverse, and every fade
window would be subtly wrong in a way that looks like a timing bug.

So the platform supplies elapsed milliseconds and nothing else. Every curve is
applied by the plan. That is also why the spring is solved here rather than
delegated: no platform spring exposes the settling threshold, and the settling
duration is what every fade window is a fraction of.

## Why the text is shaped whole

A morph draws one glyph run per segment, with the glyphs, advances and
positions all taken out of the runs of the whole-line shaping. Measured, at
every system text style: that is identical to the same line drawn in one call,
pixel for pixel.

Measuring each segment on its own is not. Summing per-character advances gains
11.29pt on 157pt at 26pt, and 21.09pt on 287pt at 48pt, because the error
accumulates. Measuring cumulative prefixes stays under 1.7pt and lands exactly
on the whole-line width, so that is the fallback where CoreText cannot be
reached; summing isolated advances never is.

Two consequences follow from drawing rather than composing views. There is no
automatic line breaking: a line exists only where the value put one, and the
container overflows rather than reflowing, because reflowing would change which
segments are adjacent and so change the whole morph. And the value cannot be
selected, in any mode.

## Why there is one rendering path

A plain `Text` would be the obvious thing to draw when nothing is moving, and
it would bring selection with it. It is not used, because it does not land in
the same place: SwiftUI gives a `Text` its own line box by a rule of its own,
about a point shallower than the font's metrics at 26pt. Toggling `disabled` or
the reduce-motion setting would shift the value vertically, and reproducing
that rule would mean depending on a private detail free to change with the OS.

So the canvas draws in every mode, and what bridges a morph to the text around
it is its published first baseline rather than a matching box. There is a test
recording the difference, which will fail if SwiftUI ever changes its rule.

## Two directions that are load bearing

A segment that survives, or arrives, is displaced by the **inverse** delta: it
starts where it used to be and animates to nothing. A segment that leaves is
displaced by the **forward** delta of whatever it anchors to: it starts at
nothing and travels to where that anchor went. They are two halves of the same
gesture, and swapping either makes the whole morph read backwards.

The search direction matters for the same reason. A segment arriving looks
backwards for a survivor first, so it enters from the text that was already
there; a segment leaving looks forwards first, so it recedes towards the text
taking its place.

## A run replaced as one shape

Six or more adjacent segments all leaving, or all arriving, carry no
displacement at all and scale about the run's own centre. Below that the
characters are near enough to animate individually; past it nothing that
survived is close enough and the run smears.

A run broken by a survivor is no replacement: that survivor is right there to
move relative to.

## A digit's slot

Two nested transforms. The slot takes the displacement; the character inside it
takes the vertical slide, clipped to the slot. Keeping the slide off the slot is
what lets a digit cross a whole line box without the next morph measuring it as
having moved.

The slot's edges are softened over 0.15em, always and not only while something
is sliding, because upstream masks the slot positionally rather than on a timer
so the softness stays in step with the slide at any duration. At rest the band
falls where a digit has no ink, so it is invisible.

## Interruption

A new value arriving mid-morph does three things.

The morph in flight is cancelled, once, and its segments' displacement and
opacity are carried into the new plan. The scale is not: upstream reads exactly
those two back off the running animation, so a segment interrupted mid-shrink
snaps to full size and carries on from where it had travelled to.

Anything already on its way out keeps its own clock. It becomes a ghost: a plan
of its own, with its own start time, dropped when its fade closes.

The container's two axes run independently, each with its own place in the
clock, so an axis whose target has not moved resumes at the phase it had
reached rather than replaying the opening sliver of its curve. Without that, a
value updating faster than the morph settles has a box that crawls while the
text races ahead.

## Where the port stops

Dictionary word breaking is not implemented, so a Japanese, Chinese or Thai
letter run stays one word where ICU would cut it into lexical words. Upstream
already segments those languages by grapheme whenever the value has no space,
which is the common case, so the difference is confined to spaced CJK.

Bidi reordering is not modelled. A segment is a contiguous logical range, and
under bidi its visual extent can be split across two runs.
