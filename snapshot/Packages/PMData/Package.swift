// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PMData",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PMData", type: .static, targets: ["PMData"])
    ],
    dependencies: [
        .package(path: "../PMDomain"),
        .package(path: "../PMUtilities"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "PMData",
            dependencies: [
                "PMDomain",
                "PMUtilities",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/PMData"
        ),
        .testTarget(
            name: "PMDataTests",
            dependencies: ["PMData"],
            path: "Tests/PMDataTests"
        )
    ]
)
