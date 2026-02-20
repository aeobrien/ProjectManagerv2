// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PMServices",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PMServices", type: .static, targets: ["PMServices"])
    ],
    dependencies: [
        .package(path: "../PMData"),
        .package(path: "../PMDomain"),
        .package(path: "../PMUtilities")
    ],
    targets: [
        .target(
            name: "PMServices",
            dependencies: ["PMData", "PMDomain", "PMUtilities"],
            path: "Sources/PMServices"
        ),
        .testTarget(
            name: "PMServicesTests",
            dependencies: ["PMServices"],
            path: "Tests/PMServicesTests"
        )
    ]
)
