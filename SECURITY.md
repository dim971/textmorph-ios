# Security policy

## Supported versions

This library is pre-1.0. Fixes land on `main` and go out in the next tagged
release; there are no maintained branches for older tags yet.

## Reporting a vulnerability

Please **do not** open a public issue for a security problem.

Use GitHub's private reporting instead: go to the **Security** tab of this
repository and choose **Report a vulnerability**. That opens a private advisory
visible only to the maintainers.

Please include what you were doing, what happened, and how to reproduce it. You
can expect an acknowledgement within a few days, and to be kept informed until
it is resolved.

## Scope

This is a text rendering library with no network access, no persistence, no
credentials and no dependencies. The plausible surface is small, and it is
about input: a value that makes the engine crash, hang, or use unbounded
memory. That is a real risk here rather than a theoretical one, because the
diff pairs words against each other and the number matcher aligns digit runs,
so a long or pathological value costs more than a short one. Upstream caps both
at a million comparison cells and twenty-five hundred pairings and degrades
past them; if you find a value that gets past those caps, or one that makes the
segmenter loop, that is worth reporting.
