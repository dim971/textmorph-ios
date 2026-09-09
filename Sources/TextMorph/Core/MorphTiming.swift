// The timing constants, gathered from torph's
// packages/torph/src/lib/utils/animate.ts and
// packages/torph/src/lib/text-morph/utils/{animate,number-animate,replace-animate}.ts.
//
// Every one of these is upstream's value under upstream's name. They are here
// rather than beside the code that uses them because the Android twin has to
// carry the same table, and a number that lives in one place is a number that
// can be compared.

/// How long each part of a morph takes, as a share of the whole.
public enum MorphTiming {
    // MARK: - opacity, always linear, always a fraction of the duration

    /// A share of the morph, never a fixed length. A cap here would leave a
    /// character opaque and motionless for the rest of a long duration.
    public static func fadeDuration(_ duration: Double, _ fraction: Double) -> Double {
        duration * fraction
    }

    /// An ordinary segment leaving fades over the first quarter.
    public static let exitFade = 0.25

    /// An ordinary segment arriving fades over half the duration, starting a
    /// quarter of the way in, so it does not appear before the segment it is
    /// replacing has gone.
    public static let enterFade = 0.5
    /// How far into the morph an arriving segment starts to fade in.
    public static let enterFadeDelay = 0.25

    /// A segment that was already part way through a fade when the next morph
    /// arrived finishes the fade over a quarter.
    public static let persistFade = 0.25

    // MARK: - numbers

    /// A digit leaving fades over nearly half the morph. Larger than the
    /// ordinary exit share on purpose: a digit that has already gone is a hole
    /// in the number.
    public static let numberExitFade = 0.45

    /// A digit arriving fades over the first quarter.
    public static let numberEnterFade = 0.25

    /// The soft edge on a digit's slot, in ems, so a digit sliding in or out
    /// does not appear at a hard line.
    public static let slotFade = 0.15

    // MARK: - a run replaced as one shape

    /// Where characters moving becomes one thing swapped for another. Past
    /// this, nothing that survived is near enough to animate from and the run
    /// smears.
    public static let groupMinimum = 6

    /// Deeper than a character's own scale, so the run reads as receding rather
    /// than as a glyph settling.
    public static let groupScale = 0.8

    /// A replaced run fades out over nearly half the morph.
    public static let groupExitFade = 0.45
    /// The run arriving in its place fades in over a third.
    public static let groupEnterFade = 0.35

    // MARK: - scale

    /// A single segment arrives from, and leaves towards, this scale.
    public static let segmentScale = 0.95

    // MARK: - carried momentum

    /// Normalised velocity is distance-relative, so a near-zero distance would
    /// otherwise launch the box across the screen.
    public static let carryMaximum = 8.0

    /// How far past its target the carry is allowed to take the curve.
    public static let carryOvershoot = 0.1

    /// Below this many points of travel there is no momentum worth carrying.
    public static let carryMinimumDelta = 0.5

    /// A target this close to the one already in flight is measurement noise,
    /// not a moved target, so the curve resumes rather than restarting. This is
    /// what keeps a fast counter's box from crawling.
    public static let sameTarget = 0.5
}
