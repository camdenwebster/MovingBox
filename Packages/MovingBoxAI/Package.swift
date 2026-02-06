// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MovingBoxAI",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "MovingBoxAIDomain",
            targets: ["MovingBoxAIDomain"]
        ),
        .library(
            name: "MovingBoxAICore",
            targets: ["MovingBoxAICore"]
        ),
    ],
    targets: [
        .target(
            name: "MovingBoxAIDomain"
        ),
        .target(
            name: "MovingBoxAICore",
            dependencies: ["MovingBoxAIDomain"]
        ),
        .testTarget(
            name: "MovingBoxAIDomainTests",
            dependencies: ["MovingBoxAIDomain"]
        ),
        .testTarget(
            name: "MovingBoxAICoreTests",
            dependencies: ["MovingBoxAICore", "MovingBoxAIDomain"]
        ),
    ]
)
