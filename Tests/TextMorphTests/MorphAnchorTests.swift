import Foundation
import Testing
@testable import TextMorph

/// The FLIP anchors and the replaced runs, against the JavaScript original.
///
/// Upstream passes DOM elements to these, but only ever asks a set whether it
/// holds one and indexes an array with it, so the generator drives them with
/// plain numbers. That makes them comparable rather than merely re-implemented.
@Suite("Anchors, against upstream")
struct MorphAnchorTests {
    let goldens: Goldens

    init() throws {
        goldens = try Fixtures.load(Goldens.self, from: "goldens")
    }

    @Test("The nearest surviving neighbour, in both search orders")
    func nearestAnchor() {
        var failures: [String] = []
        for testCase in goldens.anchors.nearest {
            let order: MorphAnchors.SearchOrder = testCase.order == "backward-first"
                ? .backwardFirst
                : .forwardFirst
            let actual = MorphAnchors.nearestAnchor(
                at: testCase.index,
                ids: testCase.ids,
                persisting: Set(testCase.persisting),
                order: order
            )
            if actual != testCase.anchor {
                failures.append(
                    "  \(testCase.ids) persisting \(testCase.persisting)"
                        + " at \(testCase.index) \(testCase.order):"
                        + " expected \(testCase.anchor ?? "nil"), got \(actual ?? "nil")"
                )
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("What each leaving segment recedes towards")
    func exitingAnchors() {
        var failures: [String] = []
        for testCase in goldens.anchors.exiting {
            let actual = MorphAnchors.exitingAnchors(
                oldIds: testCase.oldIds,
                exiting: Set(testCase.exiting),
                newIds: Set(testCase.newIds)
            )
            var expected: [Int: String] = [:]
            for (key, value) in testCase.anchors {
                guard let index = Int(key) else { continue }
                expected[index] = value
            }
            if actual != expected {
                let want = describe(expected)
                let got = describe(actual)
                failures.append(
                    "  \(testCase.oldIds) exiting \(testCase.exiting)"
                        + " to \(testCase.newIds): expected \(want), got \(got)"
                )
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("Which runs are long enough to collapse as one shape")
    func replacedRuns() {
        var failures: [String] = []
        for testCase in goldens.anchors.runs {
            let actual = MorphAnchors.replacedRuns(
                in: Array(0 ..< testCase.count), members: Set(testCase.members)
            )
            if actual != testCase.runs {
                failures.append(
                    "  \(testCase.count) segments, members \(testCase.members):"
                        + " expected \(testCase.runs), got \(actual)"
                )
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    @Test("The run minimum is six, and five is not enough")
    func runMinimum() {
        // Named rather than derived from the fixture, because the number is a
        // judgement upstream made about where movement stops reading as
        // movement, and a change to it should be deliberate.
        #expect(MorphTiming.groupMinimum == 6)
        #expect(MorphAnchors.replacedRuns(in: Array(0 ..< 6), members: Set(0 ..< 6)).count == 1)
        #expect(MorphAnchors.replacedRuns(in: Array(0 ..< 5), members: Set(0 ..< 5)).isEmpty)
    }

    @Test("How far a segment moved, and zero when it is not in both layouts")
    func deltas() {
        var previous = SegmentPositions()
        for (id, point) in goldens.anchors.previous {
            previous[id] = MorphPoint(x: point.x, y: point.y)
        }
        var current = SegmentPositions()
        for (id, point) in goldens.anchors.current {
            current[id] = MorphPoint(x: point.x, y: point.y)
        }

        var failures: [String] = []
        for testCase in goldens.anchors.deltas {
            let actual = MorphAnchors.delta(from: previous, to: current, id: testCase.id)
            if actual.dx != testCase.delta.dx || actual.dy != testCase.delta.dy {
                failures.append(
                    "  \(testCase.id): expected (\(testCase.delta.dx), \(testCase.delta.dy)),"
                        + " got (\(actual.dx), \(actual.dy))"
                )
            }
        }
        #expect(failures.isEmpty, report(failures))
    }

    private func describe(_ anchors: [Int: String]) -> String {
        anchors.keys.sorted().map { "\($0)=\(anchors[$0] ?? "")" }.joined(separator: " ")
    }

    private func report(_ failures: [String]) -> Comment {
        Comment(rawValue: "\(failures.count) disagree:\n"
            + failures.prefix(12).joined(separator: "\n"))
    }
}
