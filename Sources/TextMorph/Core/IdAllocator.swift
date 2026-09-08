// A port of torph's createIdAllocator, from
// packages/torph/src/lib/text-morph/utils/segment.ts.

/// Hands out segment identities, guaranteeing they are unique.
///
/// Uniqueness has to hold across the whole value, not per line: a collision
/// makes two segments fight over one place on screen, and one of them silently
/// loses its text.
///
/// The shape of an identity matters as much as its uniqueness. A segment's
/// identity is its own text where it can be, so the same word keeps the same
/// identity when the value is re-segmented. Only on a collision does an index
/// come into it, and only then a counter.
struct IdAllocator {
    private var used: Set<String> = []

    /// Creates an empty allocator.
    init() {}

    /// Claims an identity without handing one out, for one that will be
    /// inherited later. The diff reserves before it builds, because an
    /// inherited identity taken later would otherwise go to an earlier segment.
    mutating func reserve(_ id: String) {
        used.insert(id)
    }

    /// Whether an identity is already claimed.
    func has(_ id: String) -> Bool {
        used.contains(id)
    }

    /// The given identity, or the first free variant of it.
    mutating func take(_ base: String) -> String {
        if !used.contains(base) {
            used.insert(base)
            return base
        }
        var suffix = 1
        while used.contains("\(base)~\(suffix)") {
            suffix += 1
        }
        let id = "\(base)~\(suffix)"
        used.insert(id)
        return id
    }
}
