// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "JasonetteApp",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .visionOS(.v1)],
    products: [
        .library(name: "Jasonette", targets: ["Jasonette"]),
        .library(name: "JasonetteApp-iOS", targets: ["JasonetteApp-iOS"]),
        .library(name: "JasonetteApp-macOS", targets: ["JasonetteApp-macOS"]),
        .library(name: "JasonetteApp-tvOS", targets: ["JasonetteApp-tvOS"]),
        .library(name: "JasonetteApp-visionOS", targets: ["JasonetteApp-visionOS"]),
    ],
    targets: [
        .target(
            name: "Jasonette",
            path: "Sources/Jasonette"
        ),
        .target(
            name: "JasonetteApp-iOS",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp-iOS"
        ),
        .target(
            name: "JasonetteApp-macOS",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp-macOS"
        ),
        .target(
            name: "JasonetteApp-tvOS",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp-tvOS"
        ),
        .target(
            name: "JasonetteApp-visionOS",
            dependencies: ["Jasonette"],
            path: "Sources/JasonetteApp-visionOS"
        ),
        .testTarget(
            name: "JasonetteTests",
            dependencies: ["Jasonette"],
            path: "Tests/JasonetteTests"
        ),
    ]
)
