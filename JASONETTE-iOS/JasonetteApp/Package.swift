// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "JasonetteApp",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Jasonette", targets: ["Jasonette"]),
    ],
    targets: [
        .target(
            name: "Jasonette",
            path: "Sources/Jasonette"
        ),
        .executableTarget(
            name: "JasonetteApp",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp"
        ),
        .testTarget(
            name: "JasonetteTests",
            dependencies: ["Jasonette"],
            path: "Tests/JasonetteTests"
        ),
    ]
)
