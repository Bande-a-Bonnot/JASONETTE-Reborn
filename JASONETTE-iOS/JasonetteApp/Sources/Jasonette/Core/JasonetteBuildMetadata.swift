import Foundation

/// Build provenance embedded into the app bundle for TestFlight/release verification.
public struct JasonetteBuildMetadata: Equatable {
    public let version: String
    public let build: String
    public let gitCommit: String
    public let gitBranch: String
    public let ciWorkflow: String
    public let ciBuildNumber: String
    public let generatedAt: String

    public init(
        version: String,
        build: String,
        gitCommit: String,
        gitBranch: String,
        ciWorkflow: String,
        ciBuildNumber: String,
        generatedAt: String
    ) {
        self.version = version
        self.build = build
        self.gitCommit = gitCommit
        self.gitBranch = gitBranch
        self.ciWorkflow = ciWorkflow
        self.ciBuildNumber = ciBuildNumber
        self.generatedAt = generatedAt
    }

    public static func current(bundle: Bundle = .main) -> JasonetteBuildMetadata {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

    public static func from(infoDictionary: [String: Any]) -> JasonetteBuildMetadata {
        JasonetteBuildMetadata(
            version: stringValue(for: "CFBundleShortVersionString", in: infoDictionary),
            build: stringValue(for: "CFBundleVersion", in: infoDictionary),
            gitCommit: stringValue(for: "JasonetteGitCommit", in: infoDictionary),
            gitBranch: stringValue(for: "JasonetteGitBranch", in: infoDictionary),
            ciWorkflow: stringValue(for: "JasonetteCIWorkflow", in: infoDictionary),
            ciBuildNumber: stringValue(for: "JasonetteCIBuildNumber", in: infoDictionary),
            generatedAt: stringValue(for: "JasonetteBuildGeneratedAt", in: infoDictionary)
        )
    }

    public var shortGitCommit: String {
        guard gitCommit.count > 12 else { return gitCommit }
        return String(gitCommit.prefix(12))
    }

    public var displayText: String {
        [
            "Version: \(version) (\(build))",
            "Commit: \(shortGitCommit)",
            "Branch: \(gitBranch)",
            "Xcode Cloud build: \(ciBuildNumber)",
            "Workflow: \(ciWorkflow)",
            "Generated: \(generatedAt)",
        ].joined(separator: "\n")
    }

    private static func stringValue(for key: String, in dictionary: [String: Any]) -> String {
        guard let value = dictionary[key] else { return "unknown" }
        let string = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        return string.isEmpty ? "unknown" : string
    }
}
