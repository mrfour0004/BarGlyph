// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BarGlyph",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "BarGlyph", targets: ["BarGlyph"]),
    ],
    targets: [
        .target(name: "BarGlyph"),
        .testTarget(
            name: "BarGlyphTests",
            dependencies: ["BarGlyph"]
        ),
    ]
)
