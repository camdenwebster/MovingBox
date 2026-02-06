import ProjectDescription

let project = Project(
    name: "MovingBoxModules",
    organizationName: "MotherSound",
    packages: [
        .local(path: "Packages/MovingBoxAI")
    ],
    targets: [
        .target(
            name: "MovingBoxModules",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.mothersound.movingbox.modules",
            deploymentTargets: .iOS("18.0"),
            sources: ["TuistSupport/Sources/**"],
            dependencies: [
                .package(product: "MovingBoxAIDomain"),
                .package(product: "MovingBoxAICore"),
            ]
        ),
        .testTarget(
            name: "MovingBoxModulesTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.mothersound.movingbox.modules.tests",
            deploymentTargets: .iOS("18.0"),
            sources: ["TuistSupport/Tests/**"],
            dependencies: [
                .target(name: "MovingBoxModules")
            ]
        ),
    ]
)
