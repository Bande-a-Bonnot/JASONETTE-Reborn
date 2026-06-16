import XCTest
@testable import Jasonette

final class BuildMetadataTests: XCTestCase {
    func testReadsBundleInfoValues() {
        let metadata = JasonetteBuildMetadata.from(infoDictionary: [
            "CFBundleShortVersionString": "2.0.0",
            "CFBundleVersion": "99",
            "JasonetteGitCommit": "976075eabcdef1234567890",
            "JasonetteGitBranch": "main",
            "JasonetteCIWorkflow": "TestFlight",
            "JasonetteCIBuildNumber": "99",
            "JasonetteBuildGeneratedAt": "2026-06-14T18:30:00Z",
        ])

        XCTAssertEqual(metadata.version, "2.0.0")
        XCTAssertEqual(metadata.build, "99")
        XCTAssertEqual(metadata.gitCommit, "976075eabcdef1234567890")
        XCTAssertEqual(metadata.shortGitCommit, "976075eabcde")
        XCTAssertEqual(metadata.gitBranch, "main")
        XCTAssertEqual(metadata.ciWorkflow, "TestFlight")
        XCTAssertEqual(metadata.ciBuildNumber, "99")
        XCTAssertEqual(metadata.generatedAt, "2026-06-14T18:30:00Z")
    }

    func testMissingAndBlankValuesUseUnknown() {
        let metadata = JasonetteBuildMetadata.from(infoDictionary: [
            "CFBundleShortVersionString": "",
            "CFBundleVersion": "100",
        ])

        XCTAssertEqual(metadata.version, "unknown")
        XCTAssertEqual(metadata.build, "100")
        XCTAssertEqual(metadata.gitCommit, "unknown")
        XCTAssertEqual(metadata.gitBranch, "unknown")
        XCTAssertEqual(metadata.ciWorkflow, "unknown")
        XCTAssertEqual(metadata.ciBuildNumber, "unknown")
        XCTAssertEqual(metadata.generatedAt, "unknown")
    }

    func testDisplayTextIncludesReleaseTraceabilityFields() {
        let metadata = JasonetteBuildMetadata(
            version: "2.0.0",
            build: "99",
            gitCommit: "976075eabcdef1234567890",
            gitBranch: "main",
            ciWorkflow: "Release",
            ciBuildNumber: "99",
            generatedAt: "2026-06-14T18:30:00Z"
        )

        let displayText = metadata.displayText
        XCTAssertTrue(displayText.contains("Version: 2.0.0 (99)"))
        XCTAssertTrue(displayText.contains("Commit: 976075eabcde"))
        XCTAssertTrue(displayText.contains("Branch: main"))
        XCTAssertTrue(displayText.contains("Xcode Cloud build: 99"))
    }
}
