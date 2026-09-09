// Turning two layouts and a diff into a plan.
//
// This replaces upstream's flip.ts together with the orchestration half of
// text-morph/index.ts. See MorphPlanner.swift for the two directions that are
// load bearing.

// MARK: - the segments that leave

extension MorphPlanner {
    /// Which segments are going, what each recedes towards, and which of them
    /// form a run long enough to recede as one shape.
    struct Departures {
        let exiting: Set<Int>
        let anchors: [Int: String]
        let inARun: Set<Int>
        let runCentres: [Int: MorphPoint]
    }

    static func departures(_ input: MorphPlanInput) -> Departures {
        let newIds = Set(input.newSegments.map(\.id))
        let oldBoxes = input.oldLayout.boxes
        let oldIds = oldBoxes.map(\.id)

        var exiting = Set<Int>()
        for (index, id) in oldIds.enumerated() where !newIds.contains(id) {
            exiting.insert(index)
        }

        let runs = MorphAnchors.replacedRuns(
            in: Array(oldBoxes.indices), members: exiting
        )
        return Departures(
            exiting: exiting,
            anchors: MorphAnchors.exitingAnchors(
                oldIds: oldIds, exiting: exiting, newIds: newIds
            ),
            inARun: Set(runs.flatMap(\.self)),
            runCentres: centres(of: runs, in: oldBoxes)
        )
    }

    static func leaving(_ input: MorphPlanInput) -> [SegmentAnimation] {
        let departures = departures(input)
        guard !departures.exiting.isEmpty else { return [] }

        let oldBoxes = input.oldLayout.boxes
        let strings = stringsById(input.oldSegments)
        let kinds = kindsById(input.oldSegments)

        var out: [SegmentAnimation] = []
        for index in oldBoxes.indices where departures.exiting.contains(index) {
            let box = oldBoxes[index]
            let context = ExitContext(
                box: box,
                string: strings[box.id] ?? "",
                kind: kinds[box.id] ?? nil,
                start: carriedStart(input, id: box.id)
            )

            if let centre = departures.runCentres[index], departures.inARun.contains(index) {
                out.append(groupExit(context, centre: centre))
                continue
            }

            // The forward delta: where the anchor went, so the segment follows
            // the text taking its place.
            let delta = departures.anchors[index].map {
                MorphAnchors.delta(
                    from: input.newLayout.positions, to: input.oldLayout.positions, id: $0
                )
            } ?? (dx: 0, dy: 0)

            out.append(context.kind == nil
                ? textExit(context, delta: delta, scales: input.scale)
                : numberExit(context, delta: delta, slideDistance: input.newLayout.slideDistance))
        }
        return out
    }

    /// The four things every exit needs, gathered so each shape below reads as
    /// one statement.
    struct ExitContext {
        let box: SegmentBox
        let string: String
        let kind: SegmentKind?
        let start: SegmentState
    }

    /// A whole run receding as one shape: no displacement at all, only a scale
    /// about the centre the run shares.
    private static func groupExit(_ context: ExitContext, centre: MorphPoint) -> SegmentAnimation {
        SegmentAnimation(
            id: context.box.id, string: context.string, kind: context.kind,
            role: .groupExit, source: .old, box: context.box,
            from: SegmentState(opacity: context.start.opacity),
            to: SegmentState(scale: MorphTiming.groupScale, opacity: 0),
            fadeWindow: .fraction(MorphTiming.groupExitFade),
            scaleOrigin: centre
        )
    }

    /// A digit or a symbol leaving: the slot follows the anchor, the character
    /// inside it slides out along the block axis.
    private static func numberExit(
        _ context: ExitContext, delta: (dx: Double, dy: Double), slideDistance: Double
    ) -> SegmentAnimation {
        SegmentAnimation(
            id: context.box.id, string: context.string, kind: context.kind,
            role: .numberExit, source: .old, box: context.box,
            from: SegmentState(opacity: context.start.opacity),
            to: SegmentState(
                dx: delta.dx, dy: delta.dy, opacity: 0, moverDy: slideDistance
            ),
            fadeWindow: .fraction(MorphTiming.numberExitFade),
            scaleOrigin: context.box.centre
        )
    }

    private static func textExit(
        _ context: ExitContext, delta: (dx: Double, dy: Double), scales: Bool
    ) -> SegmentAnimation {
        SegmentAnimation(
            id: context.box.id, string: context.string, kind: nil,
            role: .exit, source: .old, box: context.box,
            from: SegmentState(opacity: context.start.opacity),
            to: SegmentState(
                dx: delta.dx, dy: delta.dy,
                scale: scales ? MorphTiming.segmentScale : 1,
                opacity: 0
            ),
            fadeWindow: .fraction(MorphTiming.exitFade),
            scaleOrigin: context.box.centre
        )
    }
}
