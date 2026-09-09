#if canImport(AppKit)
    import AppKit
    import CoreGraphics
    import Foundation
    import SwiftUI
    import Testing

    /// Reading and comparing what a view actually drew.
    ///
    /// Plumbing rather than a claim: it is here so the suite next door reads as
    /// the handful of statements it is making, rather than as bitmap handling
    /// with a few assertions in it.
    extension CanvasRenderTests {
        func alpha(of image: CGImage) -> [UInt8]? {
            pixels(of: image)?.enumerated()
                .filter { $0.offset % 4 == 3 }
                .map(\.element)
        }

        func pixels(of image: CGImage) -> [UInt8]? {
            let width = image.width
            let height = image.height
            var buffer = [UInt8](repeating: 0, count: width * height * 4)
            guard let context = CGContext(
                data: &buffer, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return buffer
        }

        struct Difference {
            let maxChannel: Int
            let differing: Int
            let total: Int
        }

        /// Which rows of pixels differ at all, which says whether a difference
        /// is an edge effect or a shift.
        func differingRows(_ a: CGImage, _ b: CGImage) -> [Int]? {
            guard a.width == b.width, a.height == b.height,
                  let left = pixels(of: a), let right = pixels(of: b) else { return nil }

            var rows: [Int] = []
            for row in 0 ..< a.height {
                let start = row * a.width * 4
                for index in stride(from: start, to: start + a.width * 4, by: 4) {
                    let differs = (0 ..< 4).contains {
                        abs(Int(left[index + $0]) - Int(right[index + $0])) > 1
                    }
                    if differs {
                        rows.append(row)
                        break
                    }
                }
            }
            return rows
        }

        func compare(_ a: CGImage, _ b: CGImage) -> Difference? {
            guard a.width == b.width, a.height == b.height,
                  let left = pixels(of: a), let right = pixels(of: b) else { return nil }

            var maxChannel = 0
            var differing = 0
            for index in stride(from: 0, to: left.count, by: 4) {
                var worst = 0
                for channel in 0 ..< 4 {
                    worst = max(worst, abs(Int(left[index + channel]) - Int(right[index + channel])))
                }
                if worst > 0 { differing += 1 }
                maxChannel = max(maxChannel, worst)
            }
            return Difference(maxChannel: maxChannel, differing: differing, total: left.count / 4)
        }
    }
#endif
