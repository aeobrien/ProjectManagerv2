// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PMFeatures",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PMFeatures", type: .static, targets: ["PMFeatures"])
    ],
    dependencies: [
        .package(path: "../PMServices"),
        .package(path: "../PMDesignSystem"),
        .package(path: "../PMData"),
        .package(path: "../PMDomain"),
        .package(path: "../PMUtilities")
    ],
    targets: [
        .target(
            name: "PMFeatures",
            dependencies: ["PMServices", "PMDesignSystem", "PMData", "PMDomain", "PMUtilities"],
            path: "Sources/PMFeatures"
        ),
        .testTarget(
            name: "PMFeaturesTests",
            dependencies: ["PMFeatures"],
            path: "Tests/PMFeaturesTests"
        )
    ]
)
