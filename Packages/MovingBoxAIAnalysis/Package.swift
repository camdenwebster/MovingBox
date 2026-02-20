// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MovingBoxAIAnalysis",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "MovingBoxAIAnalysis", targets: ["MovingBoxAIAnalysis"])
    ],
    dependencies: [
        .package(url: "https://github.com/lzell/AIProxySwift", from: "0.127.0")
    ],
    targets: [
        .target(
            name: "MovingBoxAIAnalysis",
            dependencies: [.product(name: "AIProxy", package: "AIProxySwift")]
        ),
        .testTarget(
            name: "MovingBoxAIAnalysisTests",
            dependencies: ["MovingBoxAIAnalysis"],
            path: "Tests/MovingBoxAIAnalysisTests"
        ),
    ]
)
