// Turning two layouts and a diff into a plan.
//
// This replaces upstream's flip.ts together with the orchestration half of
// text-morph/index.ts. See MorphPlanner.swift for the two directions that are
// load bearing.

// MARK: - the segments that arrive, and the ones that stay

extension MorphPlanner {
    /// Which segments have a box to be displaced from, and which of the ones
    /// that do not form a run long enough to arrive as one shape.
    struct Arrivals {
        let persisting: Set<String>
        let arriving: Set<Int>
        let inARun: Set<Int>
        let runCentres: [Int: MorphPoint]
    }

    static func arrivals(_ input: MorphPlanInput) -> Arrivals {
        let newBoxes = input.newLayout.boxes
        let newIds = newBoxes.map(\.id)
        let oldPositions = input.oldLayout.positions

        // A segment with a box in the old layout has somewhere to be displaced
        // from; one without has to borrow a neighbour's displacement.
        let persisting = Set(newIds.filter { oldPositions.contains($0) })
        var arriving = Set<Int>()
        for (index, id) in newIds.enumerated() where !persisting.contains(id) {
            arriving.insert(index)
        }

        let runs = MorphAnchors.replacedRuns(
            in: Array(newBoxes.indices), members: arriving
        )
        return Arrivals(
            persisting: persisting,
            arriving: arriving,
            inARun: Set(runs.flatMap(\.self)),
            runCentres: centres(of: runs, in: newBoxes)
        )
    }

    static func arrivingAndPersisting(_ input: MorphPlanInput) -> [SegmentAnimation] {
        let newBoxes = input.newLayout.boxes
        let newIds = newBoxes.map(\.id)
        let oldPositions = input.oldLayout.positions
        let arrivals = arrivals(input)
        let strings = stringsById(input.newSegments)
        let kinds = kindsById(input.newSegments)

        var out: [SegmentAnimation] = []
        for index in newBoxes.indices {
            let box = newBoxes[index]
            // The stand-in that holds the line box open while a value empties
            // is not something the reader should see arrive.
            if box.id == Segment.emptyID { continue }

            let string = strings[box.id] ?? ""
            let kind = kinds[box.id] ?? nil
            let isNew = arrivals.arriving.contains(index)
            let start = carriedStart(input, id: box.id)

            if let centre = arrivals.runCentres[index], arrivals.inARun.contains(index) {
                out.append(SegmentAnimation(
                    id: box.id, string: string, kind: kind,
                    role: .groupEnter, source: .new, box: box,
                    from: SegmentState(scale: MorphTiming.groupScale, opacity: 0),
                    to: SegmentState(opacity: 1),
                    fadeWindow: .fraction(MorphTiming.groupEnterFade),
                    scaleOrigin: centre
                ))
                continue
            }

            // The inverse delta, against the first-frame layout: the segment
            // starts where it used to be and animates to nothing. A segment
            // with no previous box of its own borrows a surviving neighbour's,
            // looking backwards first so it enters from the text already there.
            let anchorId = isNew
                ? MorphAnchors.nearestAnchor(
                    at: index, ids: newIds,
                    persisting: arrivals.persisting, order: .backwardFirst
                )
                : box.id
            let delta = anchorId.map {
                MorphAnchors.delta(
                    from: oldPositions, to: input.firstFrameLayout.positions, id: $0
                )
            } ?? (dx: 0, dy: 0)

            if let kind {
                out.append(numberAnimation(
                    box: box, string: string, kind: kind, isNew: isNew,
                    delta: delta, start: start, slideDistance: input.newLayout.slideDistance
                ))
            } else {
                out.append(textAnimation(
                    box: box, string: string, isNew: isNew, delta: delta, start: start
                ))
            }
        }
        return out
    }

    /// A character of a number: the slot takes the displacement, the character
    /// inside it takes the slide.
    ///
    /// Digits arrive from above and symbols from below, so each reads as its
    /// own event rather than as the whole number shifting.
    static func numberAnimation(
        box: SegmentBox, string: String, kind: SegmentKind, isNew: Bool,
        delta: (dx: Double, dy: Double), start: SegmentState, slideDistance: Double
    ) -> SegmentAnimation {
        let slideFrom = kind == .digit ? -slideDistance : slideDistance
        return SegmentAnimation(
            id: box.id, string: string, kind: kind,
            role: isNew ? .numberEnter : .numberPersist,
            source: .new, box: box,
            from: SegmentState(
                dx: delta.dx + start.dx, dy: delta.dy + start.dy,
                opacity: isNew ? 0 : start.opacity,
                moverDy: isNew ? start.moverDy + slideFrom : 0
            ),
            to: SegmentState(opacity: 1),
            fadeWindow: isNew
                ? .fraction(MorphTiming.numberEnterFade)
                : .fraction(MorphTiming.persistFade),
            scaleOrigin: box.centre
        )
    }

    static func textAnimation(
        box: SegmentBox, string: String, isNew: Bool,
        delta: (dx: Double, dy: Double), start: SegmentState
    ) -> SegmentAnimation {
        // A segment already fully opaque and merely moving needs no fade at
        // all, which is why upstream only animates opacity when it starts below
        // one. Here that is the window collapsing to nothing.
        let startOpacity = isNew ? 0 : start.opacity
        return SegmentAnimation(
            id: box.id, string: string, kind: nil,
            role: isNew ? .enter : .persist,
            source: .new, box: box,
            from: SegmentState(
                dx: delta.dx + start.dx, dy: delta.dy + start.dy,
                scale: isNew ? MorphTiming.segmentScale : 1,
                opacity: startOpacity
            ),
            to: SegmentState(opacity: 1),
            fadeWindow: isNew
                ? .fraction(MorphTiming.enterFade, after: MorphTiming.enterFadeDelay)
                : (startOpacity < 1 ? .fraction(MorphTiming.persistFade) : TimeWindow(start: 0, end: 0)),
            scaleOrigin: box.centre
        )
    }
}
