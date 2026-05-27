import ProjectDescription

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
    ]),
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
