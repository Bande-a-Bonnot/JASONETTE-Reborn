import XCTest
@testable import Jasonette

@MainActor
final class ViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeDocument(_ json: [String: Any]) -> JasonDocument {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonDocument.self, from: data)
    }

    private func simpleDocument(title: String = "Test", actions: [String: Any]? = nil) -> JasonDocument {
        var head: [String: Any] = ["title": title]
        if let actions { head["actions"] = actions }
        return makeDocument([
            "$jason": [
                "head": head,
                "body": [
                    "sections": [
                        ["items": [["type": "label", "text": "Hello"]]]
                    ]
                ]
            ]
        ])
    }

    // MARK: - Load state transitions

    func testLoadIfNeededTransitionsToLoaded() async {
        let doc = simpleDocument()
        let vm = JasonetteViewModel(document: doc)
        XCTAssertEqual(vm.loadState, .idle)
        await vm.loadIfNeeded()
        XCTAssertEqual(vm.loadState, .loaded)
    }

    func testLoadIfNeededDoesNotReloadWhenLoaded() async {
        let doc = simpleDocument()
        let vm = JasonetteViewModel(document: doc)
        await vm.loadIfNeeded()
        XCTAssertEqual(vm.loadState, .loaded)
        // Call again — should remain loaded without re-loading
        await vm.loadIfNeeded()
        XCTAssertEqual(vm.loadState, .loaded)
    }

    // MARK: - Render fallback

    func testRenderFallsBackToRawDocumentWithoutTemplates() async {
        let doc = makeDocument([
            "$jason": [
                "head": ["title": "No Templates"],
                "body": [
                    "sections": [
                        ["items": [["type": "label", "text": "Raw"]]]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertNotNil(vm.renderedRoot)
        XCTAssertEqual(vm.renderedRoot?.head?.title, "No Templates")
    }

    // MARK: - handleHref notifications

    func testHandleHrefPostsNotification() async {
        let doc = simpleDocument()
        let vm = JasonetteViewModel(document: doc)

        let expectation = expectation(forNotification: .jasonetteNavigate, object: nil) { notification in
            guard let url = notification.userInfo?["url"] as? URL else { return false }
            return url.absoluteString == "https://example.com"
        }

        let href = JasonHref(url: "https://example.com", view: "push")
        vm.handleHref(href)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleHrefBackPostsBackTrue() async {
        let doc = simpleDocument()
        let vm = JasonetteViewModel(document: doc)

        let expectation = expectation(forNotification: .jasonetteNavigate, object: nil) { notification in
            notification.userInfo?["back"] as? Bool == true
        }

        let href = JasonHref(url: nil, view: "$back")
        vm.handleHref(href)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleHrefClosePostsCloseTrue() async {
        let doc = simpleDocument()
        let vm = JasonetteViewModel(document: doc)

        let expectation = expectation(forNotification: .jasonetteNavigate, object: nil) { notification in
            notification.userInfo?["close"] as? Bool == true
        }

        let href = JasonHref(url: nil, view: "$close")
        vm.handleHref(href)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - handlePull

    func testHandlePullCallsLoadWhenNoPullAction() async {
        let doc = simpleDocument()
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        // handlePull with no $pull action calls load()
        await vm.handlePull()
        XCTAssertEqual(vm.loadState, .loaded)
    }

    func testHandlePullExecutesPullAction() async {
        let doc = simpleDocument(actions: [
            "$pull": ["type": "$set", "options": ["pulled": true]]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        await vm.handlePull()
        XCTAssertEqual(vm.stateManager.get()["pulled"] as? Bool, true)
    }

    // MARK: - Template rendering (crash fix coverage)

    func testRenderWithTemplatedDocumentDoesNotCrash() async {
        // This document uses head.templates — triggers the render() path that previously crashed.
        // AnyCodable-wrapped values must be unwrapped before JSONSerialization.
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "Template Test",
                    "data": ["greeting": "Hello", "count": 3],
                    "templates": [
                        "body": [
                            "sections": [
                                [
                                    "items": [
                                        ["type": "label", "text": "{{greeting}}"]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ],
                "body": ["sections": []]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertNotNil(vm.renderedRoot)
    }

    func testRenderWithAnyCodableDataProducesValidOutput() async {
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "Data Test",
                    "data": ["name": "World", "items": ["a", "b", "c"]],
                    "templates": [
                        "body": [
                            "sections": [[
                                "items": [[
                                    "{{#each items}}": ["type": "label", "text": "{{$jason}}"]
                                ]]
                            ]]
                        ]
                    ]
                ],
                "body": ["sections": []]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertNotNil(vm.renderedRoot)
    }

    func testRenderFallsBackToRawDocumentWhenTemplateInvalid() async {
        // A document with templates that render to invalid JSON falls back gracefully
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "Invalid",
                    "templates": ["body": ["sections": "not-an-array"]]
                ],
                "body": ["sections": []]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        // Template renders sections as a string, which fails decode → falls back to raw doc
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertNotNil(vm.renderedRoot)
    }

    // MARK: - Body background color

    func testBodyBackgroundHexColorFlowsThrough() async {
        let doc = makeDocument([
            "$jason": [
                "head": ["title": "BG Test"],
                "body": [
                    "background": "#ff0000",
                    "sections": [
                        ["items": [["type": "label", "text": "Red bg"]]]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertEqual(vm.renderedRoot?.body?.background?.string, "#ff0000")
    }

    func testBodyBackgroundRGBColorFlowsThrough() async {
        let doc = makeDocument([
            "$jason": [
                "head": ["title": "BG RGB"],
                "body": [
                    "background": "rgb(0,255,0)",
                    "sections": [
                        ["items": [["type": "label", "text": "Green bg"]]]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertEqual(vm.renderedRoot?.body?.background?.string, "rgb(0,255,0)")
    }

    func testBodyWithoutBackgroundRendersNormally() async {
        let doc = makeDocument([
            "$jason": [
                "head": ["title": "No BG"],
                "body": [
                    "sections": [
                        ["items": [["type": "label", "text": "No background"]]]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertNil(vm.renderedRoot?.body?.background)
    }

    func testBodyWithInvalidBackgroundColorDoesNotCrash() async {
        let doc = makeDocument([
            "$jason": [
                "head": ["title": "Invalid BG"],
                "body": [
                    "background": "not-a-color",
                    "sections": [
                        ["items": [["type": "label", "text": "Bad bg"]]]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        // The string is present but Color(css:) will return nil — no crash
        XCTAssertEqual(vm.renderedRoot?.body?.background?.string, "not-a-color")
    }

    // MARK: - $load lifecycle

    func testLoadLifecycleActionFires() async {
        let doc = simpleDocument(actions: [
            "$load": ["type": "$set", "options": ["loaded_lifecycle": true]]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.stateManager.get()["loaded_lifecycle"] as? Bool, true)
    }
}
