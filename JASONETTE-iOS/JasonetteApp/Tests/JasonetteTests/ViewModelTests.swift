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

    func testPreloadedDocumentURLIsPreservedSeparatelyFromIdentityURL() async {
        let identityURL = URL(string: "https://example.com/app/index.json")!
        let documentURL = URL(string: "https://cdn.example.com/final/index.json")!
        let vm = JasonetteViewModel(url: identityURL, preloadedDoc: simpleDocument(), documentURL: documentURL)
        await vm.loadIfNeeded()
        XCTAssertEqual(vm.documentURL, documentURL)
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

    // MARK: - handleHref → NavigationRequest dispatch

    /// Captures the most recent `NavigationRequest` emitted by a viewmodel.
    /// Used instead of the old global NotificationCenter-based assertions so
    /// tests exercise the same scoped dispatch path the UI uses.
    private final class NavigationCapture {
        var requests: [NavigationRequest] = []
        var last: NavigationRequest? { requests.last }
    }

    private func makeViewModelCapturing(_ doc: JasonDocument) -> (JasonetteViewModel, NavigationCapture) {
        let capture = NavigationCapture()
        let vm = JasonetteViewModel(document: doc, onNavigate: { capture.requests.append($0) })
        return (vm, capture)
    }

    func testHandleHrefDefaultTransitionEmitsPush() {
        let (vm, capture) = makeViewModelCapturing(simpleDocument())
        vm.handleHref(JasonHref(url: "https://example.com", view: nil))
        guard case .push(let url) = capture.last else {
            return XCTFail("Expected .push, got \(String(describing: capture.last))")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com")
    }

    func testHandleHrefTransitionSwitchEmitsSwitchTab() {
        let (vm, capture) = makeViewModelCapturing(simpleDocument())
        vm.handleHref(JasonHref(url: "https://example.com/tab2", view: nil, transition: "switch"))
        guard case .switchTab(let url) = capture.last else {
            return XCTFail("Expected .switchTab, got \(String(describing: capture.last))")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com/tab2")
    }

    func testHandleHrefTransitionModalEmitsModal() {
        let (vm, capture) = makeViewModelCapturing(simpleDocument())
        vm.handleHref(JasonHref(url: "https://example.com/detail", view: nil, transition: "modal"))
        guard case .modal(let url) = capture.last else {
            return XCTFail("Expected .modal, got \(String(describing: capture.last))")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com/detail")
    }

    func testHandleHrefViewWebEmitsWeb() {
        let (vm, capture) = makeViewModelCapturing(simpleDocument())
        vm.handleHref(JasonHref(url: "https://example.com", view: "web"))
        guard case .web(let url) = capture.last else {
            return XCTFail("Expected .web, got \(String(describing: capture.last))")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com")
    }

    func testHandleHrefViewAppAllowsMailto() {
        let (vm, capture) = makeViewModelCapturing(simpleDocument())
        vm.handleHref(JasonHref(url: "mailto:test@example.com", view: "app"))
        guard case .app(let url) = capture.last else {
            return XCTFail("Expected .app, got \(String(describing: capture.last))")
        }
        XCTAssertEqual(url.scheme, "mailto")
    }

    func testHandleHrefBackEmitsBack() {
        let (vm, capture) = makeViewModelCapturing(simpleDocument())
        vm.handleHref(JasonHref(url: nil, view: "$back"))
        guard case .back = capture.last else {
            return XCTFail("Expected .back, got \(String(describing: capture.last))")
        }
    }

    func testHandleHrefCloseEmitsClose() {
        let (vm, capture) = makeViewModelCapturing(simpleDocument())
        vm.handleHref(JasonHref(url: nil, view: "$close"))
        guard case .close = capture.last else {
            return XCTFail("Expected .close, got \(String(describing: capture.last))")
        }
    }

    func testHandleHrefRejectsDisallowedScheme() {
        let (vm, capture) = makeViewModelCapturing(simpleDocument())
        vm.handleHref(JasonHref(url: "file:///etc/passwd", view: nil))
        XCTAssertNil(capture.last, "Disallowed scheme must not dispatch a navigation")
    }

    func testHandleHrefDefaultHandlerIsNoop() {
        // A viewmodel constructed without a navigation handler must not crash
        // on handleHref — the default handler is a no-op so callers can work
        // without wiring (tests, previews, future headless rendering).
        let vm = JasonetteViewModel(document: simpleDocument())
        vm.handleHref(JasonHref(url: "https://example.com", view: nil))
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

    // MARK: - Preload seed + reload (Codex review round 2 regression)

    /// BLOCKER 1: a VM constructed with `init(url:preloadedDoc:)` renders the
    /// seed on first load without hitting the network. The seed's head
    /// title must appear in `renderedRoot`.
    func testPreloadSeedRendersFirstLoadWithoutFetch() async {
        let seed = simpleDocument(title: "Seed Title")
        let vm = JasonetteViewModel(
            url: URL(string: "https://not-reachable.invalid/x.json")!,
            preloadedDoc: seed
        )
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded, "seed should render without fetch")
        XCTAssertEqual(vm.renderedRoot?.head?.title, "Seed Title")
    }

    /// BLOCKER 1: once the seed has been rendered, subsequent `load()` calls
    /// must refetch from `url` — otherwise `$reload`/retry/pull-to-refresh
    /// forever re-renders the stale seed. Proof: point the VM at a blocked
    /// scheme (`file://`). `DocumentLoader` rejects it synchronously with
    /// `DocumentError.blockedURL`, so the second load must reach `.error` —
    /// deterministic and offline, no DNS-timeout variance.
    func testPreloadSeedRefetchesOnSecondLoad() async {
        let seed = simpleDocument(title: "Seed Title")
        let vm = JasonetteViewModel(
            url: URL(string: "file:///tmp/definitely-not-allowed.json")!,
            preloadedDoc: seed
        )
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded, "first load uses seed")

        await vm.load()
        if case .error = vm.loadState {
            // Expected: DocumentLoader rejects the blocked scheme.
        } else {
            XCTFail("second load must refetch — got \(vm.loadState) instead of .error")
        }
    }
}
