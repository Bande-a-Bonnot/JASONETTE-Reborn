import XCTest
@testable import Jasonette

@MainActor
final class URLResolutionTests: XCTestCase {
    private let baseURL = URL(string: "https://example.com/app/index.json")!

    private func decodeComponent(_ json: [String: Any]) -> JasonComponent {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonComponent.self, from: data)
    }

    private func decodeFooter(_ json: [String: Any]) -> JasonFooter {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonFooter.self, from: data)
    }

    func testJasonURLResolvesRelativePathBesideDocument() {
        XCTAssertEqual(
            JasonURL.resolve("images/logo.png", against: baseURL),
            URL(string: "https://example.com/app/images/logo.png")!
        )
    }

    func testJasonURLResolvesLeadingSlashAtOriginRoot() {
        XCTAssertEqual(
            JasonURL.resolve("/images/logo.png", against: baseURL),
            URL(string: "https://example.com/images/logo.png")!
        )
    }

    func testJasonURLAllowedSchemesRunsAfterResolution() {
        XCTAssertEqual(
            JasonURL.resolve("api/items", against: baseURL, allowedSchemes: DocumentLoader.allowedSchemes),
            URL(string: "https://example.com/app/api/items")!
        )
        XCTAssertNil(
            JasonURL.resolve("file:///tmp/secret", against: baseURL, allowedSchemes: DocumentLoader.allowedSchemes)
        )
    }

    func testImageComponentResolvesRelativeURLAgainstDocumentURL() {
        let image = ImageComponent(url: "images/logo.png", style: nil, documentURL: baseURL)
        XCTAssertEqual(image.resolvedURL, URL(string: "https://example.com/app/images/logo.png")!)
    }

    func testButtonComponentResolvesRootRelativeURLAgainstDocumentURL() {
        let button = ButtonComponent(text: "Open", url: "/icons/open.png", documentURL: baseURL)
        XCTAssertEqual(button.resolvedURL, URL(string: "https://example.com/icons/open.png")!)
    }

    func testFooterInputButtonResolvesRelativeImageURLAgainstDocumentURL() {
        let footer = decodeFooter([
            "input": [
                "name": "message",
                "left": ["image": "icons/camera.png"]
            ]
        ])
        let inputView = FooterInputView(input: footer.input!, onAction: nil, documentURL: baseURL)
        XCTAssertEqual(
            inputView.resolvedImageURL(for: footer.input!.left!),
            URL(string: "https://example.com/app/icons/camera.png")!
        )
    }

    func testLegacyFooterTabItemResolvesRelativeIconURLAgainstDocumentURL() {
        let item = decodeComponent([
            "image": "icons/home.png",
            "url": "home.json",
            "text": "Home"
        ])
        let tabItem = FooterTabItemView(
            item: item,
            headStyles: [:],
            onHref: nil,
            onAction: nil,
            documentURL: baseURL
        )
        XCTAssertEqual(tabItem.resolvedIconURL, URL(string: "https://example.com/app/icons/home.png")!)
    }

    func testLegacyFooterTabItemDetectsCurrentDocumentTarget() {
        let item = decodeComponent(["url": "index.json", "text": "Current"])
        let tabItem = FooterTabItemView(
            item: item,
            headStyles: [:],
            onHref: nil,
            onAction: nil,
            documentURL: baseURL
        )
        var href = JasonHref()
        href.url = "index.json"

        XCTAssertTrue(tabItem.resolvesToCurrentDocument(href))
    }

    func testLegacyFooterTabItemAllowsDifferentDocumentTarget() {
        let item = decodeComponent(["url": "settings.json", "text": "Settings"])
        let tabItem = FooterTabItemView(
            item: item,
            headStyles: [:],
            onHref: nil,
            onAction: nil,
            documentURL: baseURL
        )
        var href = JasonHref()
        href.url = "settings.json"

        XCTAssertFalse(tabItem.resolvesToCurrentDocument(href))
    }

    func testLegacyFooterTabItemAccessibilityLabelPrefersAuthoredText() {
        let item = decodeComponent([
            "image": "icons/home.png",
            "url": "home.json",
            "text": "Home"
        ])
        let tabItem = FooterTabItemView(
            item: item,
            headStyles: [:],
            onHref: nil,
            onAction: nil,
            documentURL: baseURL,
            fallbackAccessibilityLabel: "Tab 1"
        )

        XCTAssertEqual(tabItem.accessibilityLabelText, "Home")
    }

    func testLegacyFooterTabItemAccessibilityLabelUsesFallbackForIconOnlyTabs() {
        let item = decodeComponent([
            "image": "https://example.com/assets/0.png",
            "url": "index.json"
        ])
        let tabItem = FooterTabItemView(
            item: item,
            headStyles: [:],
            onHref: nil,
            onAction: nil,
            documentURL: baseURL,
            fallbackAccessibilityLabel: "Tab 2"
        )

        XCTAssertEqual(tabItem.accessibilityLabelText, "Tab 2")
    }
}
