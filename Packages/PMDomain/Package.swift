// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PMDomain",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PMDomain", type: .static, targets: ["PMDomain"])
    ],
    dependencies: [
        .package(path: "../PMUtilities")
    ],
    targets: [
        .target(
            name: "PMDomain",
            dependencies: ["PMUtilities"],
            path: "Sources/PMDomain"
        ),
        .testTarget(
            name: "PMDomainTests",
            dependencies: ["PMDomain"],
            path: "Tests/PMDomainTests"
        )
    ]
)
