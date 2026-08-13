// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WorkIsland",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WorkIsland", targets: ["WorkIsland"])
    ],
    targets: [
        .executableTarget(
            name: "WorkIsland",
            path: "Sources/WorkIsland"
        ),
        .testTarget(
            name: "WorkIslandTests",
            dependencies: ["WorkIsland"],
            path: "Tests/WorkIslandTests"
        )
    ]
)
