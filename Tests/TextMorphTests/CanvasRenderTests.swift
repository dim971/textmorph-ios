#if canImport(AppKit)
    import AppKit
    import Foundation
    import SwiftUI
    import Testing
    @testable import TextMorph

    /// What the canvas actually draws.
    ///
    /// The probe that settled the rendering design compared pixels outside the
    /// package; this does it through the code that ships. The claim is that a
    /// value drawn one glyph run per segment comes out identical to the same
    /// line drawn in one call, and it holds exactly, at every size.
    ///
    /// It did not hold at first, and the failure is the reason these tests
    /// exist. A shaper reports a glyph's position within the line it shaped, so
    /// drawing a segment from the segment's own x counts the offset twice: the
    /// first word landed correctly and everything after it went off the end of
    /// the canvas. Three tests that only checked something had been drawn all
    /// passed while that was true.
    ///
    /// macOS only: `ImageRenderer` needs a window server, and the package
    /// declares macOS so the suite can run without a simulator.
    @Suite("What the canvas draws", .serialized)
    @MainActor
    struct CanvasRenderTests {
        private let value = "AVATAR Wave 1,234.56"

        init() {
            // ImageRenderer will not produce an image without an initialised
            // application, and a test binary has none by default.
            let app = NSApplication.shared
            app.setActivationPolicy(.prohibited)
        }

        /// A settled morph, and the layout it settled into.
        private func settled(
            _ text: String, font: TextMorphFont = .system(size: 26)
        ) -> Settled {
            let store = LayoutStore(font: font)
            let engine = MorphEngine(store: store)
            engine.update(.text(text), now: Date())
            let render = engine.render(at: Date())!
            return Settled(
                store: store, plan: render.plan, frame: render.frame,
                size: engine.size(at: Date()),
                // The segmenter normalises a space to U+00A0, so the line the
                // layout shaped is not the value that was passed in. Comparing
                // against the raw value would compare two different strings and
                // blame the segmenting for it.
                lineText: LineLayout.lines(
                    of: TextSegmenter.segmentText(text)
                )[0].text
            )
        }

        private struct Settled {
            let store: LayoutStore
            let plan: MorphPlan
            let frame: MorphFrame
            let size: MorphSize
            let lineText: String
        }

        @Test("A value at rest is drawn, and is drawn where the layout says")
        func drawsSomething() throws {
            let settled = settled(value)
            let image = try #require(render(canvas(settled), size: settled.size))

            let pixels = try #require(alpha(of: image))
            let inked = pixels.filter { $0 > 0 }.count
            #expect(inked > 0, "the canvas drew nothing at all")
            // A line of text covers a fair part of its box but nowhere near all
            // of it. Either extreme means the transform is wrong.
            let share = Double(inked) / Double(pixels.count)
            #expect(share > 0.05, Comment(rawValue: "only \(share) of the box is inked"))
            #expect(share < 0.6, Comment(rawValue: "\(share) of the box is inked, which is too much"))
        }

        @Test("Cutting a value into segments costs nothing at all")
        func segmentingIsFree() throws {
            // The claim the whole rendering design rests on, measured through
            // the code that ships rather than through a probe: a value drawn
            // one glyph run per segment is identical to the same line drawn in
            // one call. Exactly identical, at every size.
            var report: [String] = []

            // No numeric word in it. A number's characters sit in masked
            // slots, which are always slightly soft at the top and bottom, so
            // they are the subject of the next test rather than this one.
            let plain = "AVATAR Wave Total balance"
            for size in [11.0, 13.0, 17.0, 26.0, 48.0] {
                let font = TextMorphFont.system(size: size)
                let settled = settled(plain, font: font)

                let segmented = try #require(render(canvas(settled), size: settled.size))
                let whole = try #require(render(
                    WholeLineDraw(
                        store: settled.store,
                        text: settled.lineText,
                        top: 0,
                        colour: black
                    ),
                    size: settled.size
                ))

                let difference = try #require(compare(segmented, whole))
                report.append("  \(size)pt: max channel \(difference.maxChannel),"
                    + " differing \(difference.differing) of \(difference.total)")
                #expect(
                    difference.maxChannel == 0,
                    Comment(rawValue: "splitting the value changed the drawing:\n"
                        + report.joined(separator: "\n"))
                )
            }
        }

        @Test("A digit sliding in stays inside its own slot")
        func slotsClipTheSlide() throws {
            // The load-bearing half of the slot. An entering digit starts a
            // whole line box above where it will settle, so without the clip it
            // would be drawn above the value entirely, over whatever is there.
            // Every segment of this value is a number's character, so nothing
            // at all should appear outside the container's box.
            let store = LayoutStore(font: .system(size: 26))
            let engine = MorphEngine(store: store)
            let start = Date()
            engine.update(.text("1,204"), now: start)
            engine.update(.text("1,318"), now: start)

            var sawInk = false
            for fraction in [0.0, 0.15, 0.3, 0.5, 0.8] {
                let now = start.addingTimeInterval(0.4 * fraction)
                let render = try #require(engine.render(at: now))
                let size = engine.size(at: now)
                let canvas = TextMorphCanvas(
                    plan: render.plan, frame: render.frame, ghosts: render.ghosts,
                    store: store, size: size, colour: black, debug: false
                )
                // Rendered at the canvas's own size, uncropped, so the margin
                // the container does not cover is visible.
                let image = try #require(renderUncropped(canvas))
                let bleed = Int(canvas.bleed * 2)

                let alpha = try #require(self.alpha(of: image))
                var outside = 0
                for row in 0 ..< image.height {
                    for column in 0 ..< image.width {
                        let inside = row >= bleed && row < image.height - bleed
                            && column >= bleed && column < image.width - bleed
                        if inside { continue }
                        if alpha[row * image.width + column] > 1 { outside += 1 }
                    }
                }
                #expect(
                    outside == 0,
                    Comment(rawValue: "\(outside) pixels of a digit escaped its slot"
                        + " at \(fraction) of the way through")
                )
                if alpha.contains(where: { $0 > 1 }) { sawInk = true }
            }
            #expect(sawInk, "nothing was drawn at any point in the morph")
        }

        @Test("A morph sits where its own metrics say, not where a Text would")
        func boxDiffersFromText() throws {
            // Recorded rather than asserted away. SwiftUI gives a `Text` its own
            // line box by a rule of its own, about a point shallower than the
            // font's ascent plus descent plus leading at 26pt, so a morph and a
            // `Text` in identical frames do not land on the same row of pixels.
            // That is why there is one rendering path and why baseline
            // alignment is what bridges a morph to the text around it, rather
            // than a matching box.
            let font = TextMorphFont.system(size: 26)
            let settled = settled(value, font: font)

            let ours = try #require(render(canvas(settled), size: settled.size))
            let theirs = try #require(render(
                Text(settled.lineText)
                    .font(font.swiftUIFont)
                    .foregroundStyle(Color.black)
                    .fixedSize()
                    .frame(
                        width: settled.size.width, height: settled.size.height,
                        alignment: .topLeading
                    ),
                size: settled.size
            ))

            let difference = try #require(compare(ours, theirs))
            // The same glyphs, in the same places horizontally, a little over a
            // point apart vertically. If this ever becomes zero, SwiftUI
            // changed its rule and the note above is out of date.
            #expect(difference.maxChannel > 0, "SwiftUI's line box now matches the font's")
            #expect(
                Double(difference.differing) < Double(difference.total) * 0.35,
                Comment(rawValue: "\(difference.differing) of \(difference.total) differ,"
                    + " which is more than a row or two of pixels")
            )
        }

        @Test("Part way through a morph, everything is somewhere sensible")
        func midMorph() throws {
            let store = LayoutStore(font: .system(size: 26))
            let engine = MorphEngine(store: store)
            let start = Date()
            engine.update(.text("1,204"), now: start)
            engine.update(.text("1,318"), now: start)

            for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let now = start.addingTimeInterval(0.4 * fraction)
                let render = try #require(engine.render(at: now))
                let size = engine.size(at: now)
                let view = TextMorphCanvas(
                    plan: render.plan, frame: render.frame, ghosts: render.ghosts,
                    store: store, size: size, colour: black, debug: false
                )
                let image = try #require(
                    self.render(view, size: size),
                    "no image at \(fraction) of the way through"
                )
                let inked = try #require(alpha(of: image)).filter { $0 > 0 }.count
                #expect(inked > 0, "nothing drawn at \(fraction) of the way through")
            }
        }

        @Test("Debug mode draws more than plain mode, and nothing else changes")
        func debugMode() throws {
            let settled = settled(value)
            let plain = try #require(render(canvas(settled), size: settled.size))
            let debugged = try #require(render(canvas(settled, debug: true), size: settled.size))

            let plainInk = try #require(alpha(of: plain)).filter { $0 > 0 }.count
            let debugInk = try #require(alpha(of: debugged)).filter { $0 > 0 }.count
            #expect(debugInk > plainInk, "debug mode should draw the boxes as well")
        }

        // MARK: - helpers

        /// The same line, drawn in one call rather than one call per segment.
        private struct WholeLineDraw: View {
            let store: LayoutStore
            let text: String
            let top: Double
            let colour: Color.Resolved

            var body: some View {
                Canvas(
                    opaque: false, colorMode: .nonLinear, rendersAsynchronously: false
                ) { context, _ in
                    context.withCGContext { cg in
                        cg.setFillColor(CGColor(
                            red: CGFloat(colour.red), green: CGFloat(colour.green),
                            blue: CGFloat(colour.blue), alpha: CGFloat(colour.opacity)
                        ))
                        let shaped = store.shapedLine(for: text)
                        shaped.draw(
                            shaped.glyphs,
                            at: CGPoint(x: 0, y: top + shaped.metrics.ascent),
                            in: cg
                        )
                    }
                }
            }
        }

        private var black: Color.Resolved {
            Color.Resolved(red: 0, green: 0, blue: 0, opacity: 1)
        }

        private func canvas(_ settled: Settled, debug: Bool = false) -> TextMorphCanvas {
            TextMorphCanvas(
                plan: settled.plan, frame: settled.frame, ghosts: [],
                store: settled.store, size: settled.size, colour: black, debug: debug
            )
        }

        /// Renders a view at the container's size, with the canvas pulled back
        /// into place the way the real view pulls it.
        private func render(_ view: some View, size: MorphSize, scale: CGFloat = 2) -> CGImage? {
            let bleed = (view as? TextMorphCanvas)?.bleed ?? 0
            let renderer = ImageRenderer(
                content: Color.clear
                    .frame(width: size.width, height: size.height)
                    .overlay(alignment: .topLeading) {
                        view.offset(x: -bleed, y: -bleed)
                    }
            )
            renderer.scale = scale
            renderer.isOpaque = false
            return renderer.cgImage
        }

        /// Renders a canvas at its own size, margin included.
        private func renderUncropped(_ canvas: TextMorphCanvas, scale: CGFloat = 2) -> CGImage? {
            let renderer = ImageRenderer(content: canvas)
            renderer.scale = scale
            renderer.isOpaque = false
            return renderer.cgImage
        }
    }
#endif
