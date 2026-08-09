// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PMUtilities",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PMUtilities", type: .static, targets: ["PMUtilities"])
    ],
    targets: [
        .target(
            name: "PMUtilities",
            path: "Sources/PMUtilities"
        ),
        .testTarget(
            name: "PMUtilitiesTests",
            dependencies: ["PMUtilities"],
            path: "Tests/PMUtilitiesTests"
        )
    ]
)
