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

    func testJasonetteCanonicalNormalizesUserVisibleHTTPDifferences() {
        let url = URL(string: "HTTPS://Example.COM:443/app/../home/?b=2&a=1")!

        XCTAssertEqual(url.jasonetteCanonical.absoluteString, "https://example.com/home?a=1&b=2")
    }

    func testJasonetteCanonicalDropsHTTPDefaultPortOnlyForMatchingScheme() {
        XCTAssertEqual(
            URL(string: "http://example.com:80/home")!.jasonetteCanonical.absoluteString,
            "http://example.com/home"
        )
        XCTAssertEqual(
            URL(string: "https://example.com:80/home")!.jasonetteCanonical.absoluteString,
            "https://example.com:80/home"
        )
    }

    func testJasonetteCanonicalPreservesNonDefaultQueryAndFragment() {
        let url = URL(string: "https://example.com:8443/home/?b=2&a=1#section")!

        XCTAssertEqual(url.jasonetteCanonical.absoluteString, "https://example.com:8443/home?a=1&b=2#section")
    }

    func testImageComponentResolvesRelativeURLAgainstDocumentURL() {
        let image = ImageComponent(url: "images/logo.png", style: nil, documentURL: baseURL)
        XCTAssertEqual(image.resolvedURL, URL(string: "https://example.com/app/images/logo.png")!)
    }

    func testImageComponentRejectsUnsafeImageSchemes() {
        XCTAssertNil(ImageComponent(url: "file:///tmp/logo.png", style: nil, documentURL: baseURL).resolvedURL)
        XCTAssertNil(ImageComponent(url: "custom://logo", style: nil, documentURL: baseURL).resolvedURL)
    }

    func testImageComponentSelectsAnimatedGIFRendererForRelativeGIFURL() {
        let image = ImageComponent(url: "images/spinner.gif", style: nil, documentURL: baseURL)
        XCTAssertEqual(image.resolvedURL, URL(string: "https://example.com/app/images/spinner.gif")!)
        XCTAssertTrue(image.usesAnimatedGIFRenderer)
    }

    func testImageComponentKeepsStaticImagesOnAsyncPath() {
        let image = ImageComponent(url: "images/logo.png", style: nil, documentURL: baseURL)
        XCTAssertFalse(image.usesAnimatedGIFRenderer)
    }

    func testGIFDetectionIgnoresQueryString() {
        XCTAssertTrue(URL(string: "https://example.com/image.gif?cache=1")!.isGIFImageURL)
    }

    func testGIFDetectionRejectsNonGIFExtension() {
        XCTAssertFalse(URL(string: "https://example.com/image.png")!.isGIFImageURL)
    }

    func testButtonComponentResolvesRootRelativeURLAgainstDocumentURL() {
        let button = ButtonComponent(text: "Open", url: "/icons/open.png", documentURL: baseURL)
        XCTAssertEqual(button.resolvedURL, URL(string: "https://example.com/icons/open.png")!)
    }

    func testButtonComponentUsesImageFallbackURL() {
        let component = decodeComponent([
            "type": "button",
            "text": "Camera",
            "image": "icons/camera.png"
        ])
        let button = ButtonComponent(component: component, documentURL: baseURL)
        XCTAssertEqual(button.resolvedURL, URL(string: "https://example.com/app/icons/camera.png")!)
    }

    func testButtonComponentRejectsUnsafeImageSchemes() {
        XCTAssertNil(ButtonComponent(text: nil, url: "file:///tmp/button.png", documentURL: baseURL).resolvedURL)
        XCTAssertNil(ButtonComponent(text: nil, url: "custom://button", documentURL: baseURL).resolvedURL)
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

    func testFooterInputButtonRejectsUnsafeImageSchemes() {
        let footer = decodeFooter([
            "input": [
                "left": ["image": "file:///tmp/camera.png"],
                "right": ["image": "custom://send"]
            ]
        ])
        let inputView = FooterInputView(input: footer.input!, onAction: nil, documentURL: baseURL)
        XCTAssertNil(inputView.resolvedImageURL(for: footer.input!.left!))
        XCTAssertNil(inputView.resolvedImageURL(for: footer.input!.right!))
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

    func testLegacyFooterTabItemRejectsUnsafeIconSchemes() {
        for image in ["file:///tmp/home.png", "custom://home"] {
            let item = decodeComponent(["image": image, "url": "home.json"])
            let tabItem = FooterTabItemView(
                item: item,
                headStyles: [:],
                onHref: nil,
                onAction: nil,
                documentURL: baseURL
            )
            XCTAssertNil(tabItem.resolvedIconURL)
        }
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

    func testLegacyFooterTabItemDetectsCurrentDocumentTargetWithCanonicalURL() {
        let documentURL = URL(string: "https://Example.com:443/app/index.json?a=1&b=2")!
        let item = decodeComponent(["url": "index.json", "text": "Current"])
        let tabItem = FooterTabItemView(
            item: item,
            headStyles: [:],
            onHref: nil,
            onAction: nil,
            documentURL: documentURL
        )
        var href = JasonHref()
        href.url = "https://example.com/app/index.json/?b=2&a=1"

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
