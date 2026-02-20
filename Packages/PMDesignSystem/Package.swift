// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PMDesignSystem",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PMDesignSystem", type: .static, targets: ["PMDesignSystem"])
    ],
    dependencies: [
        .package(path: "../PMDomain"),
        .package(path: "../PMUtilities")
    ],
    targets: [
        .target(
            name: "PMDesignSystem",
            dependencies: ["PMDomain", "PMUtilities"],
            path: "Sources/PMDesignSystem"
        ),
        .testTarget(
            name: "PMDesignSystemTests",
            dependencies: ["PMDesignSystem"],
            path: "Tests/PMDesignSystemTests"
        )
    ]
)
