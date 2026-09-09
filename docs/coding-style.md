# Coding style

The [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
as they apply here, plus the places this project deliberately differs.

## Naming

`Core` keeps upstream's names. `segmentText`, `diffSegments`, `lcsIndices`,
`placeMatch`, `numericSkeleton`: they are not idiomatic Swift and they are not
meant to be. When a golden fails, the two files have to be readable side by
side, and a renamed function costs more in that moment than it earns in every
other.

Everything above `Core` is named for a Swift reader.

## Documentation

Every public declaration carries a doc comment; SwiftLint enforces it. A doc
comment says what the thing is for, and where a value looks arbitrary it says
where the value came from. "0.45" means nothing; "a digit that has already left
is a hole in the number, so the outgoing share is larger" means something.

## Comments explain why, not what

The code says what it does. A comment is for the reason, and in a port the
reason is usually "upstream does this, and here is what breaks if it does not".

Two kinds of comment are especially worth writing here:

- **A reproduced quirk.** Anything that looks like a mistake and is deliberate
  needs to say so, or the next reader fixes it and a golden turns red with no
  explanation.
- **A measurement.** Numbers that came out of a probe rather than out of a
  document belong next to the code that depends on them. "11.29pt on 157pt at
  26pt" is checkable; "measuring segments separately drifts" is not.

## Units

`Core` counts string positions in UTF-16 code units, never in `Character`
counts, because upstream does and because the two disagree on any value holding
an astral character. `UTF16Offset` exists so the wrong number cannot be passed
by accident, and `Core` takes no `String.Index` anywhere.

Distances are in points. Times are in milliseconds, because upstream's are.

## Generated files

`UnicodeBreakTables.swift` is generated and is excluded from linting. Nothing
about it is meant to be read. The same goes for the two fixture files.

A generator names, in its own header, the exact command that produces its
output and the upstream version it is pinned to. Regenerating is a deliberate
act.

## No em dash

No em dash (U+2014) and no en dash (U+2013). Not in code, comments, docs,
commit messages or issue and pull request text. Use a comma, a colon, a
semicolon, parentheses or a full stop. CI fails the build if either character
reappears, and `make dashes` runs the same check.

## What is enforced mechanically

| Rule | Enforced by |
| --- | --- |
| Formatting, wrapping, spacing | `swiftformat --lint` |
| A doc comment on every public declaration | SwiftLint `missing_docs` |
| Line length, nesting, complexity, file and function length | SwiftLint |
| Zero build warnings | CI rebuilds and greps |
| No em dash or en dash | CI, and `make dashes` |
| The engine matches the original | the golden fixtures |
| The two ports match each other | the fixture and generator digests, in CI |

Everything else in this document is a review conversation.

Two SwiftLint rules are disabled in named places, both times around a chain
where each branch is one named rule of UAX #29. A function boundary in the
middle of a rule sequence would break the one property that makes those
checkable against the standard. Where a threshold could be satisfied by a real
refactor instead, it was: the diff and the planner are each three files for
that reason.

SwiftFormat yields to SwiftLint on the brace of a multiline declaration, and
keeps one-line bodies. Both are written down in `.swiftformat` with the reason,
rather than left to whichever version CI installs.
