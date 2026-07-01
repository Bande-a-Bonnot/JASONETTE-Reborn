import Foundation
import ProjectDescription

func environmentValue(_ keys: String...) -> String? {
    for key in keys {
        let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if value?.isEmpty == false { return value }
    }
    return nil
}

func shellValue(_ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }

    guard process.terminationStatus == 0 else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return value?.isEmpty == false ? value : nil
}

func iso8601Now() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: Date())
}

let buildMetadataSettings: [String: SettingValue] = [
    "JASONETTE_GIT_COMMIT": .string(
        environmentValue("JASONETTE_GIT_COMMIT", "CI_COMMIT")
            ?? shellValue(["git", "rev-parse", "HEAD"])
            ?? "unknown"
    ),
    "JASONETTE_GIT_BRANCH": .string(
        environmentValue("JASONETTE_GIT_BRANCH", "CI_BRANCH")
            ?? shellValue(["git", "rev-parse", "--abbrev-ref", "HEAD"])
            ?? "unknown"
    ),
    "JASONETTE_CI_WORKFLOW": .string(
        environmentValue("JASONETTE_CI_WORKFLOW", "CI_WORKFLOW")
            ?? "Xcode Cloud"
    ),
    "JASONETTE_CI_BUILD_NUMBER": .string(
        environmentValue("JASONETTE_CI_BUILD_NUMBER", "CI_BUILD_NUMBER")
            ?? "$(CURRENT_PROJECT_VERSION)"
    ),
    "JASONETTE_BUILD_GENERATED_AT": .string(
        environmentValue("JASONETTE_BUILD_GENERATED_AT", "CI_BUILD_ID")
            ?? iso8601Now()
    ),
]

let automaticSigningSettings: Settings = .settings(
    base: [
        "CODE_SIGN_STYLE": "Automatic",
        "DEVELOPMENT_TEAM": "PKPPLFK854",
    ],
    defaultSettings: .recommended(excluding: ["CODE_SIGN_IDENTITY"])
)

let project = Project(
    name: "Jasonette",
    packages: [
        .local(path: "."),
    ],
    settings: .settings(base: [
        "MARKETING_VERSION": "2.0.0",
        "CURRENT_PROJECT_VERSION": "1",
    ].merging(buildMetadataSettings) { _, new in new }),
    targets: [
        // MARK: - iOS
        .target(
            name: "Jasonette-iOS",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.bande-a-bonnot.jasonette",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": ["UIColorName": "", "UIImageName": ""],
                "CFBundleDisplayName": "Jasonette",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "ITSAppUsesNonExemptEncryption": false,
                "JasonetteGitCommit": "$(JASONETTE_GIT_COMMIT)",
                "JasonetteGitBranch": "$(JASONETTE_GIT_BRANCH)",
                "JasonetteCIWorkflow": "$(JASONETTE_CI_WORKFLOW)",
                "JasonetteCIBuildNumber": "$(JASONETTE_CI_BUILD_NUMBER)",
                "JasonetteBuildGeneratedAt": "$(JASONETTE_BUILD_GENERATED_AT)",
                "CFBundleURLTypes": [[
                    "CFBundleURLName": "com.bande-a-bonnot.jasonette.build",
                    "CFBundleURLSchemes": ["jasonette-build"],
                ]],
                "NSLocationWhenInUseUsageDescription": "Jasonette documents can request your location to render geo demos and location-aware screens.",
                "NSCameraUsageDescription": "Jasonette documents can request camera access so you can capture photos or videos for media actions.",
                "NSPhotoLibraryUsageDescription": "Jasonette documents can open your photo library when selecting media or when the camera is unavailable in Simulator.",
                "NSMicrophoneUsageDescription": "Jasonette documents can request microphone access when recording videos with the camera.",
                "NSContactsUsageDescription": "Jasonette documents can request contacts access to render address book demos and contact-aware screens.",
            ]),
            sources: [],
            resources: ["Resources/iOS/**"],
            dependencies: [.package(product: "JasonetteApp-iOS")],
            settings: automaticSigningSettings
        ),

        // MARK: - macOS
        .target(
            name: "Jasonette-macOS",
            destinations: [.mac],
            product: .app,
            bundleId: "com.bande-a-bonnot.jasonette.macos",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Jasonette",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.package(product: "JasonetteApp-macOS")],
            settings: automaticSigningSettings
        ),

        // MARK: - tvOS
        .target(
            name: "Jasonette-tvOS",
            destinations: [.appleTv],
            product: .app,
            bundleId: "com.bande-a-bonnot.jasonette.tvos",
            deploymentTargets: .tvOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Jasonette",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.package(product: "JasonetteApp-tvOS")],
            settings: automaticSigningSettings
        ),

        // MARK: - visionOS
        .target(
            name: "Jasonette-visionOS",
            destinations: [.appleVision],
            product: .app,
            bundleId: "com.bande-a-bonnot.jasonette.visionos",
            deploymentTargets: .visionOS("1.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Jasonette",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.package(product: "JasonetteApp-visionOS")],
            settings: automaticSigningSettings
        ),
    ]
)
