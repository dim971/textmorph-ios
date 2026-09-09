#!/usr/bin/env swift
// Draws the app icon.
//
//   swift Tools/gen-icon.swift Showcase/Assets.xcassets/AppIcon.appiconset/icon.png
//
// Run by hand, never in CI. The mark is the one thing this library does that no
// other text view does: a digit half way out of its slot with the next one half
// way in, clipped to the slot and soft at the edges, which is exactly the
// arrangement described in MorphTiming and drawn by TextMorphCanvas. Drawn with
// CoreGraphics rather than by the package, so the icon can be regenerated
// without building anything.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0
let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Showcase/Assets.xcassets/AppIcon.appiconset/icon.png"

guard let context = CGContext(
    data: nil, width: Int(side), height: Int(side),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("could not make a context") }

// Flip once, so everything below is written in the coordinates the rest of this
// project uses: y downwards from the top left.
context.translateBy(x: 0, y: side)
context.scaleBy(x: 1, y: -1)

let ink = CGColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
let paper = CGColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)
context.setFillColor(paper)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

let font = CTFontCreateWithName("SFPro-Semibold" as CFString, side * 0.62, nil)
let ascent = CTFontGetAscent(font)
let descent = CTFontGetDescent(font)

/// One digit, drawn at a baseline.
func draw(_ digit: String, baseline: Double, x: Double, alpha: Double) {
    // The CoreText attribute names, not the AppKit ones: this runs as a
    // script, so there is no AppKit to import.
    let attributed = NSAttributedString(string: digit, attributes: [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: ink
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    context.saveGState()
    context.setAlpha(alpha)
    context.textMatrix = .identity
    context.translateBy(x: x, y: baseline)
    context.scaleBy(x: 1, y: -1)
    context.textPosition = .zero
    CTLineDraw(line, context)
    context.restoreGState()
}

/// The width of a digit, so the slot can be centred on it.
func width(_ digit: String) -> Double {
    let attributed = NSAttributedString(
        string: digit, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]
    )
    return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)
}

// The slot: one line box, centred, with the horizontal axis left open the way
// the library leaves it open so glyph overhang is not shaved.
let slotHeight = ascent + descent
let slotTop = (side - slotHeight) / 2
let slot = CGRect(x: 0, y: slotTop, width: side, height: slotHeight)
let baseline = slotTop + ascent
let centre = (side - width("5")) / 2

context.saveGState()
context.clip(to: slot)
context.beginTransparencyLayer(auxiliaryInfo: nil)

/// A four on its way out, downwards, and a five arriving from above. The
/// fractions are one third of a line box, which is about where a roll reads
/// most clearly.
let slide = slotHeight / 3
draw("4", baseline: baseline + slide, x: centre, alpha: 0.28)
draw("5", baseline: baseline - slide * 0.15, x: centre, alpha: 1)

// The soft edge: 0.15em, the same band MorphTiming names.
let band = CTFontGetSize(font) * 0.15
let stops: [CGFloat] = [0, CGFloat(band / slotHeight), CGFloat(1 - band / slotHeight), 1]
let mask = [
    CGColor(gray: 0, alpha: 0),
    CGColor(gray: 0, alpha: 1),
    CGColor(gray: 0, alpha: 1),
    CGColor(gray: 0, alpha: 0)
]
if let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceGray(), colors: mask as CFArray, locations: stops
) {
    context.saveGState()
    context.setBlendMode(.destinationIn)
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: slot.midX, y: slot.minY),
        end: CGPoint(x: slot.midX, y: slot.maxY),
        options: []
    )
    context.restoreGState()
}

context.endTransparencyLayer()
context.restoreGState()

guard let image = context.makeImage() else { fatalError("could not make an image") }
let url = URL(fileURLWithPath: output)
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil
) else { fatalError("could not write \(output)") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not finalise \(output)") }
print("wrote \(output)")
