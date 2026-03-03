import ProjectDescription

let project = Project(
    name: "Jasonette",
    packages: [
        .local(path: "."),
    ],
    settings: .settings(base: [
        "MARKETING_VERSION": "0.1.0",
        "CURRENT_PROJECT_VERSION": "1",
    ]),
    targets: [
        // MARK: - iOS
        .target(
            name: "Jasonette-iOS",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.bande-a-bonnot.jasonette",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": ["UIColorName": "", "UIImageName": ""],
                "CFBundleDisplayName": "Jasonette",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            resources: ["Resources/iOS/**"],
            dependencies: [.package(product: "JasonetteApp-iOS")],
            settings: .settings(base: SettingsDictionary()
                .automaticCodeSigning(devTeam: "TEAM_ID_HERE"))
        ),

        // MARK: - macOS
        .target(
            name: "Jasonette-macOS",
            destinations: [.mac],
            product: .app,
            bundleId: "com.bande-a-bonnot.jasonette.macos",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Jasonette",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.package(product: "JasonetteApp-macOS")],
            settings: .settings(base: SettingsDictionary()
                .automaticCodeSigning(devTeam: "TEAM_ID_HERE"))
        ),

        // MARK: - tvOS
        .target(
            name: "Jasonette-tvOS",
            destinations: [.appleTv],
            product: .app,
            bundleId: "com.bande-a-bonnot.jasonette.tvos",
            deploymentTargets: .tvOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Jasonette",
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.package(product: "JasonetteApp-tvOS")],
            settings: .settings(base: SettingsDictionary()
                .automaticCodeSigning(devTeam: "TEAM_ID_HERE"))
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
                "ITSAppUsesNonExemptEncryption": false,
            ]),
            sources: [],
            dependencies: [.package(product: "JasonetteApp-visionOS")],
            settings: .settings(base: SettingsDictionary()
                .automaticCodeSigning(devTeam: "TEAM_ID_HERE"))
        ),
    ]
)
