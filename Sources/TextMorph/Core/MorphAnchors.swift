// A port of the arithmetic in torph's packages/torph/src/lib/utils/flip.ts, and
// of `replacedRuns` from text-morph/utils/replace-animate.ts.
//
// `measure` itself is not ported. Upstream reads each span's box back out of
// the DOM, subtracting the transform in flight so the result stays subpixel;
// this port computes both layouts itself, so the boxes are already known and
// there is nothing to read back. What remains of the file is the part that
// decides which segment a moving one takes its bearing from, and that is pure.

/// Where each segment sits, by identity, in one layout.
///
/// A dictionary rather than an array because a segment is found by identity,
/// not by position: the whole point of the diff is that position changes.
struct SegmentPositions {
    private var positions: [String: Point] = [:]

    /// A point in the container's own coordinates.
    struct Point: Hashable {
        var x: Double
        var y: Double
    }

    init() {}

    init(_ positions: [String: Point]) {
        self.positions = positions
    }

    subscript(id: String) -> Point? {
        get { positions[id] }
        set { positions[id] = newValue }
    }

    /// Whether a segment appears in this layout at all.
    func contains(_ id: String) -> Bool { positions[id] != nil }
}

/// Deciding how far each segment has to travel, and what an arriving or leaving
/// one takes its bearing from.
enum MorphAnchors {
    /// Which way to look first for a segment to take a bearing from.
    ///
    /// The direction is not a preference. A segment arriving looks backwards
    /// first, so it enters from the text that was already there; a segment
    /// leaving looks forwards first, so it recedes towards the text taking its
    /// place. Swapping them makes a morph read backwards.
    enum SearchOrder {
        case backwardFirst
        case forwardFirst
    }

    /// How far a segment moved between two layouts.
    ///
    /// Zero when the segment is absent from either, which is not a fallback so
    /// much as the correct answer: there is no displacement to speak of.
    static func delta(
        from previous: SegmentPositions, to current: SegmentPositions, id: String
    ) -> (dx: Double, dy: Double) {
        guard let p = previous[id], let c = current[id] else { return (0, 0) }
        return (dx: p.x - c.x, dy: p.y - c.y)
    }

    /// The nearest segment either side of a position that survives the change.
    ///
    /// A segment with no previous box of its own has nothing to be displaced
    /// from, so it borrows the displacement of a neighbour that does. Nil means
    /// nothing survived anywhere in the value, which is a wholesale
    /// replacement.
    static func nearestAnchor(
        at targetIndex: Int,
        ids: [String],
        persisting: Set<String>,
        order: SearchOrder = .backwardFirst
    ) -> String? {
        func backward() -> String? {
            var index = targetIndex - 1
            while index >= 0 {
                if persisting.contains(ids[index]) { return ids[index] }
                index -= 1
            }
            return nil
        }

        func forward() -> String? {
            var index = targetIndex + 1
            while index < ids.count {
                if persisting.contains(ids[index]) { return ids[index] }
                index += 1
            }
            return nil
        }

        return switch order {
        case .backwardFirst: backward() ?? forward()
        case .forwardFirst: forward() ?? backward()
        }
    }

    /// What each leaving segment recedes towards.
    ///
    /// A leaving segment cannot anchor to another leaving segment, so the
    /// surviving set is the old identities that appear in the new value *and*
    /// are not themselves on their way out.
    static func exitingAnchors(
        oldIds: [String], exiting: Set<Int>, newIds: Set<String>
    ) -> [Int: String] {
        var persisting = Set<String>()
        for (index, id) in oldIds.enumerated()
            where newIds.contains(id) && !exiting.contains(index) {
            persisting.insert(id)
        }

        var anchors: [Int: String] = [:]
        for index in oldIds.indices where exiting.contains(index) {
            if let anchor = nearestAnchor(
                at: index, ids: oldIds, persisting: persisting, order: .forwardFirst
            ) {
                anchors[index] = anchor
            }
        }
        return anchors
    }

    /// Maximal stretches of adjacent segments that are all leaving, or all
    /// arriving, and long enough to read as one thing replacing another.
    ///
    /// A run broken by a survivor is no replacement: that survivor is right
    /// there to move relative to. Below the minimum length, the characters are
    /// still near enough to each other to animate individually; past it,
    /// nothing that survived is close enough and the run smears, so it collapses
    /// towards its own centre instead.
    static func replacedRuns(in all: [Int], members: Set<Int>) -> [[Int]] {
        var runs: [[Int]] = []
        var run: [Int] = []

        func flush() {
            if run.count >= MorphTiming.groupMinimum { runs.append(run) }
            run = []
        }

        for index in all {
            if members.contains(index) {
                run.append(index)
            } else {
                flush()
            }
        }
        flush()

        return runs
    }
}
