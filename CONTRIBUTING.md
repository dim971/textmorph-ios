# Contributing

Thanks for taking a look. Issues and pull requests are both welcome.

## Getting set up

```sh
git clone https://github.com/dim971/textmorph-ios
cd textmorph-ios
make test          # the engine goldens
make showcase      # build and run the catalog app in the simulator
```

You need Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`); the showcase project is generated from
`Showcase/project.yml` rather than checked in. Regenerating the fixtures also
needs Node 20+, but that is a deliberate act rather than part of a normal
build.

## Before you open a pull request

```sh
make lint          # swiftformat --lint and swiftlint
make test
```

Three things the review will look for:

**No warnings.** Not in the package, not in the showcase, on the release
toolchain *and* the current Xcode beta. A warning that is tolerated becomes a
warning that is ignored.

**The goldens still pass.** If you touch anything under
`Sources/TextMorph/Core`, the fixtures are the contract. See
[docs/fidelity.md](docs/fidelity.md). Changing them means changing what this
library claims to be, so say why in the pull request.

**Parity with Android.** This library has a
[twin](https://github.com/dim971/textmorph-android). A change to shared
behaviour (segmentation, the diff, number alignment, the timing of a morph)
should land in both, or say plainly why it should not. The two repositories
carry byte-identical `goldens.json` and byte-identical `Tools/`, and CI checks
the digest.

## Conventions

[docs/coding-style.md](docs/coding-style.md) is the full version: the
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
as they apply here, plus the handful of places this project deliberately
differs. The short version:

- Comments explain *why*, not *what*. If a constant looks arbitrary, say where
  it came from.
- Every public declaration carries a doc comment. SwiftLint enforces it.
- `Core` keeps upstream's positional signatures and upstream's names on
  purpose, so it can be read side by side with the JavaScript when a golden
  fails.
- `Core` measures positions in UTF-16 offsets, never in `Character` counts,
  because upstream does and because the two disagree on any value containing an
  astral character.
- Commit messages describe the change and the reasoning, in prose.

## Reporting a bug

A morph is a transition between two values, so one value is never enough to
reproduce it. Give the value before, the value after, and the options in force.
If the report is about a number, say the locale: the decimal separator is the
pivot every digit alignment is measured from, and some locales group with a
non-breaking space.

## Code of conduct

Taking part means following the [Code of Conduct](CODE_OF_CONDUCT.md).
