// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TextMorph",
    // macOS is declared so `swift test` runs the engine goldens natively, with no
    // simulator in the way. The view itself is SwiftUI and works on both.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TextMorph", targets: ["TextMorph"])
    ],
    targets: [
        .target(
            name: "TextMorph",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TextMorphTests",
            dependencies: ["TextMorph"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
