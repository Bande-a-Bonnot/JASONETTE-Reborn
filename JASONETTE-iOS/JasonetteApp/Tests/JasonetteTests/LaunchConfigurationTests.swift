import XCTest
@testable import Jasonette

final class LaunchConfigurationTests: XCTestCase {
    private let defaultURL = URL(string: "https://example.com/default.json")!
    private let overrideURL = URL(string: "https://example.com/override.json")!

    func testDebugEnvironmentEntryURLOverrideWinsWhenEnabled() {
        let resolved = JasonetteLaunchConfiguration.entryURL(
            arguments: ["JasonetteApp"],
            environment: ["JASONETTE_ENTRY_URL": overrideURL.absoluteString],
            defaultURL: defaultURL,
            debugOverridesEnabled: true
        )

        XCTAssertEqual(resolved, overrideURL)
    }

    func testDebugLaunchArgumentEntryURLOverrideWinsOverEnvironment() {
        let argumentURL = URL(string: "https://example.com/from-argument.json")!
        let resolved = JasonetteLaunchConfiguration.entryURL(
            arguments: ["JasonetteApp", "-JasonetteEntryURL", argumentURL.absoluteString],
            environment: ["JASONETTE_ENTRY_URL": overrideURL.absoluteString],
            defaultURL: defaultURL,
            debugOverridesEnabled: true
        )

        XCTAssertEqual(resolved, argumentURL)
    }

    func testDebugLaunchArgumentEqualsFormIsAccepted() {
        let argumentURL = URL(string: "https://example.com/from-equals.json")!
        let resolved = JasonetteLaunchConfiguration.entryURL(
            arguments: ["JasonetteApp", "-JasonetteEntryURL=\(argumentURL.absoluteString)"],
            environment: [:],
            defaultURL: defaultURL,
            debugOverridesEnabled: true
        )

        XCTAssertEqual(resolved, argumentURL)
    }

    func testReleaseConfigurationIgnoresEntryURLOverride() {
        let resolved = JasonetteLaunchConfiguration.entryURL(
            arguments: ["JasonetteApp", "-JasonetteEntryURL", overrideURL.absoluteString],
            environment: ["JASONETTE_ENTRY_URL": overrideURL.absoluteString],
            defaultURL: defaultURL,
            debugOverridesEnabled: false
        )

        XCTAssertEqual(resolved, defaultURL)
    }

    func testOverrideRejectsNonHTTPDocumentSchemes() {
        let resolved = JasonetteLaunchConfiguration.entryURL(
            arguments: ["JasonetteApp"],
            environment: ["JASONETTE_ENTRY_URL": "file:///tmp/local.json"],
            defaultURL: defaultURL,
            debugOverridesEnabled: true
        )

        XCTAssertEqual(resolved, defaultURL)
    }
}
