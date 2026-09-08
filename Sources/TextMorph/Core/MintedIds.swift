/// Mints identities for the characters of a number that have no predecessor.
///
/// A digit that arrives in a value has nothing to inherit an identity from, so
/// it needs a fresh one. The identity has to be unique not only against the
/// value being built but against every identity still on screen, including the
/// ones on segments that are part way through leaving. A counter that only
/// climbs gives that for free.
///
/// Upstream keeps the counter in a module-global. That is unusable under Swift
/// 6 strict concurrency, and it is not reproducible even in JavaScript, since
/// the counter climbs for the life of the process and so the same call returns
/// different identities depending on what ran before it. Here the counter is an
/// object, owned by one view's engine and living exactly as long as it does.
///
/// The consequence for a caller of the standalone `segmentText` and
/// `diffSegments` utilities: identities are only comparable between calls that
/// share a minter. Pass the same one through a sequence of values, or accept
/// that a number's identities restart.
public final class MintedIds {
    /// A minted identity cannot collide with one derived from text, because a
    /// NULL is not a character any value carries.
    private static let prefix = "\u{0000}n"

    private var next = 0

    /// Creates a minter whose counter starts at zero.
    public init() {}

    /// The next identity, skipping any that are already in play.
    ///
    /// `used` is the set of identities the value being built has already taken.
    /// Upstream loops the same way, and it matters here more than it does
    /// there: this counter starts at zero for every new minter, so an identity
    /// inherited from an earlier value could otherwise be minted a second time.
    func take(avoiding used: Set<String>) -> String {
        var id = mint()
        while used.contains(id) {
            id = mint()
        }
        return id
    }

    private func mint() -> String {
        let id = "\(Self.prefix)\(next)"
        next += 1
        return id
    }
}
