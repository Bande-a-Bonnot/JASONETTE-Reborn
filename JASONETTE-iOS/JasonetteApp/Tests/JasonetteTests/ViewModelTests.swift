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
