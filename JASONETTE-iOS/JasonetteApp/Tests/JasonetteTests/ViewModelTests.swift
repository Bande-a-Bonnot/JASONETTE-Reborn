import XCTest
@testable import Jasonette

@MainActor
final class ViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeDocument(_ json: [String: Any]) -> JasonDocument {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonDocument.self, from: data)
    }

    private func loadJasonpediaDocument(_ relativePath: String) throws -> JasonDocument {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let repoRoot = testDir
            .deletingLastPathComponent() // JasonetteTests/ -> Tests/
            .deletingLastPathComponent() // Tests/ -> JasonetteApp/
            .deletingLastPathComponent() // JasonetteApp/ -> JASONETTE-iOS/
            .deletingLastPathComponent() // JASONETTE-iOS/ -> JASONETTE-Reborn/
        let url = repoRoot.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JasonDocument.self, from: data)
    }

    private func renderBodyTemplate(_ doc: JasonDocument, context: [String: Any]) throws -> JasonBody {
        let template = try XCTUnwrap(doc.jason.head?.templates?["body"]?.unwrapped)
        let rendered = TemplateEngine.render(template, context: context)
        let data = try JSONSerialization.data(withJSONObject: rendered)
        return try JSONDecoder().decode(JasonBody.self, from: data)
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

    private final class StubGeolocationProvider: GeolocationProviding {
        var result: Result<String, Error>
        private(set) var requestCount = 0

        init(result: Result<String, Error>) {
            self.result = result
        }

        func currentCoordinate() async throws -> String {
            requestCount += 1
            return try result.get()
        }
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

    func testURLLoadUpdatesDocumentURLToFinalResponseURL() async {
        let requestURL = URL(string: "https://example.com/app/index.json")!
        let finalURL = URL(string: "https://cdn.example.com/final/index.json")!
        let json = """
        {
            "$jason": {
                "head": {"title": "Redirected"},
                "body": {"sections": [{"items": [{"type": "label", "text": "Loaded"}]}]}
            }
        }
        """
        StubURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: finalURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }
        defer {
            StubURLProtocol.requestHandler = nil
            StubURLProtocol.redirectHandler = nil
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let loader = DocumentLoader(session: URLSession(configuration: config))
        let vm = JasonetteViewModel(url: requestURL, loader: loader)

        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertEqual(vm.documentURL, finalURL)
        XCTAssertEqual(vm.renderedRoot?.head?.title, "Redirected")
    }

    // MARK: - ID policy

    func testAlertConfigUsesUUIDv7() {
        let alert = JasonetteViewModel.AlertConfig(title: "Title", description: nil)

        XCTAssertEqual(alert.id.uuid.6 & 0xF0, 0x70)
        XCTAssertEqual(alert.id.uuid.8 & 0xC0, 0x80)
    }

    func testToastActionCreatesTransientNotificationNotAlert() async {
        let doc = simpleDocument(actions: [
            "$load": [
                "type": "$util.toast",
                "options": ["text": "Saved", "type": "success"]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)

        await vm.load()

        XCTAssertNil(vm.alertConfig)
        XCTAssertEqual(vm.transientNotificationConfig?.kind, .toast)
        XCTAssertEqual(vm.transientNotificationConfig?.title, "Saved")
        XCTAssertEqual(vm.transientNotificationConfig?.styleType, "success")
    }

    func testBannerActionCreatesTransientNotificationNotAlert() async {
        let doc = simpleDocument(actions: [
            "$load": [
                "type": "$util.banner",
                "options": ["title": "Hello", "description": "World", "type": "info"]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)

        await vm.load()

        XCTAssertNil(vm.alertConfig)
        XCTAssertEqual(vm.transientNotificationConfig?.kind, .banner)
        XCTAssertEqual(vm.transientNotificationConfig?.title, "Hello")
        XCTAssertEqual(vm.transientNotificationConfig?.description, "World")
        XCTAssertEqual(vm.transientNotificationConfig?.styleType, "info")
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

    func testHandleHrefResolvesRelativeURLAgainstDocumentURL() {
        let capture = NavigationCapture()
        let vm = JasonetteViewModel(
            url: URL(string: "https://entry.example.com/start.json")!,
            preloadedDoc: simpleDocument(),
            documentURL: URL(string: "https://cdn.example.com/app/index.json")!,
            onNavigate: { capture.requests.append($0) }
        )
        vm.handleHref(JasonHref(url: "details/page.json", view: nil))
        guard case .push(let url) = capture.last else {
            return XCTFail("Expected .push, got \(String(describing: capture.last))")
        }
        XCTAssertEqual(url, URL(string: "https://cdn.example.com/app/details/page.json")!)
    }

    func testHandleHrefResolvesRootRelativeURLAgainstDocumentURL() {
        let capture = NavigationCapture()
        let vm = JasonetteViewModel(
            url: URL(string: "https://entry.example.com/start.json")!,
            preloadedDoc: simpleDocument(),
            documentURL: URL(string: "https://cdn.example.com/app/index.json")!,
            onNavigate: { capture.requests.append($0) }
        )
        vm.handleHref(JasonHref(url: "/global/page.json", view: nil))
        guard case .push(let url) = capture.last else {
            return XCTFail("Expected .push, got \(String(describing: capture.last))")
        }
        XCTAssertEqual(url, URL(string: "https://cdn.example.com/global/page.json")!)
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

    func testJasonpediaTemplateIndexObjectFormItemsRenderEntries() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/template/index.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let sections = try XCTUnwrap(vm.renderedRoot?.body?.sections)
        XCTAssertGreaterThan(sections.count, 2)
        let jsonItems = try XCTUnwrap(sections[1].items)
        let nonJSONItems = try XCTUnwrap(sections[2].items)

        XCTAssertEqual(jsonItems.map { $0.components?.first?.text }, [
            "Inline Data",
            "Dynamic Data",
            "#each",
            "#if | #elseif | #else",
            "Use Javascript expressions",
            "Javascript function example",
        ])
        XCTAssertEqual(nonJSONItems.map { $0.components?.first?.text }, ["HTML", "RSS", "CSV"])
        XCTAssertEqual(jsonItems.first?.href?.url, "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/template/inline.json")
    }

    func testJasonpediaNetworkIndexObjectFormItemsRenderEntries() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/action/network/index.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let items = try XCTUnwrap(vm.renderedRoot?.body?.sections?.first?.items)

        XCTAssertEqual(items.map { $0.components?.first?.text }, [
            "imagejason",
            "eliza",
            "Microblog with user account",
        ])
        XCTAssertEqual(items.map { $0.href?.url }, [
            "https://jsonplaceholder.typicode.com",
            "eliza.json",
            "https://jsonplaceholder.typicode.com/posts",
        ])
    }

    func testJasonpediaNetworkElizaFixtureUsesLocalDocumentAndMaintainedEndpoint() throws {
        let doc = try loadJasonpediaDocument("Jasonpedia/action/network/eliza.json")
        let loadAction = try XCTUnwrap(doc.jason.head?.actions?["$load"])

        XCTAssertEqual(doc.jason.head?.title, "$network Eliza demo")
        XCTAssertEqual(loadAction.type, "$network.request")
        XCTAssertEqual(loadAction.options?["url"]?.string, "https://jsonplaceholder.typicode.com/comments?postId=1")
        XCTAssertEqual(loadAction.success?.type, "$set")
        XCTAssertEqual(loadAction.error?.type, "$set")
        XCTAssertEqual(
            loadAction.error?.options?["network_error"]?.string,
            "The maintained network demo endpoint could not be reached. Check your connection and try again."
        )
    }

    func testJasonpediaNetworkElizaFixtureRendersNetworkResponseItems() throws {
        let doc = try loadJasonpediaDocument("Jasonpedia/action/network/eliza.json")
        let body = try renderBodyTemplate(doc, context: [
            "$response": [[
                "name": "reply from maintained endpoint",
                "email": "eliza@example.com",
                "body": "Hello from the network response.",
            ]],
        ])
        let item = try XCTUnwrap(body.sections?.first?.items?.first)

        XCTAssertEqual(item.components?[0].text, "reply from maintained endpoint")
        XCTAssertEqual(item.components?[1].text, "eliza@example.com")
        XCTAssertEqual(item.components?[2].text, "Hello from the network response.")
    }

    func testJasonpediaNetworkElizaFixtureRendersHelpfulFallback() throws {
        let doc = try loadJasonpediaDocument("Jasonpedia/action/network/eliza.json")
        let body = try renderBodyTemplate(doc, context: [
            "network_error": "The demo endpoint is down. Try again later.",
        ])
        let item = try XCTUnwrap(body.sections?.first?.items?.first)

        XCTAssertEqual(item.components?[0].text, "Network demo unavailable")
        XCTAssertEqual(item.components?[1].text, "The demo endpoint is down. Try again later.")
    }

    func testJasonpediaLambdaFixtureLoadsDespiteLegacyActionShapes() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/action/lambda/index.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let sections = try XCTUnwrap(vm.renderedRoot?.body?.sections)
        XCTAssertGreaterThanOrEqual(sections.count, 4)
        let rawLambdaItems = try XCTUnwrap(sections[2].items)
        let triggerItems = try XCTUnwrap(sections[3].items)

        XCTAssertEqual(rawLambdaItems.count, 6)
        XCTAssertEqual(triggerItems.count, 6)
        XCTAssertEqual(rawLambdaItems.first?.action?.type, "$util.banner")
        XCTAssertEqual(triggerItems[1].action?.trigger, "banner")
        XCTAssertEqual(triggerItems[5].action?.successActions?.count, 2)
    }

    func testJasonpediaTimerMarioUsesOptionsActionForTicks() throws {
        let doc = try loadJasonpediaDocument("Jasonpedia/action/timer/mario.json")
        let timer = try XCTUnwrap(doc.jason.head?.actions?["$load"]?.success)
        let tickAction = try XCTUnwrap(timer.options?["action"]?.dictionary)

        XCTAssertEqual(timer.type, "$timer.start")
        XCTAssertEqual(tickAction["trigger"]?.string, "tick")
    }

    func testJasonpediaTextfieldSecureStyleSelectsSecureRendererPath() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/view/component/textfield/index.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let items = try XCTUnwrap(vm.renderedRoot?.body?.sections?.first?.items)
        XCTAssertGreaterThan(items.count, 1)
        let secureField = try XCTUnwrap(items[1].components?.first)

        XCTAssertEqual(secureField.type, "textfield")
        XCTAssertEqual(secureField.name, "secure")
        XCTAssertEqual(secureField.style?.secure?.string, "true")
        XCTAssertEqual(TextFieldComponent.fieldKind(componentType: secureField.type, style: secureField.style), .secure)
    }

    func testJasonpediaTextareaFixtureUsesDefaultEmptyAffordance() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/view/component/textarea/index.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let row = try XCTUnwrap(vm.renderedRoot?.body?.sections?.first?.items?.first)
        let textarea = try XCTUnwrap(row.components?.first)

        XCTAssertEqual(textarea.type, "textarea")
        XCTAssertEqual(textarea.name, "blank")
        XCTAssertNil(textarea.placeholder)
        XCTAssertEqual(TextAreaComponent.visiblePlaceholder(textarea.placeholder ?? ""), "Enter text")
        XCTAssertEqual(
            TextAreaComponent.accessibilityLabel(name: textarea.name ?? "", placeholder: textarea.placeholder ?? ""),
            "blank text area"
        )
    }

    func testJasonpediaHTMLComponentFixtureSelectsHTMLRendererPath() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/view/component/html/index.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let htmlComponent = try XCTUnwrap(vm.renderedRoot?.body?.sections?.first?.items?.first)

        XCTAssertEqual(htmlComponent.type, "html")
        XCTAssertTrue(ComponentView.knownComponentTypes.contains("html"))
        XCTAssertEqual(htmlComponent.css, "img{width: 100%;} p{font-family: Helvetica; font-size: 14px;}")
        XCTAssertTrue(htmlComponent.text?.contains("Continue reading") == true)
    }

    func testJasonpediaGeoFixtureRendersCoordinateAndMapFromGeoPayload() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/action/geo/index.json"))
        let provider = StubGeolocationProvider(result: .success("37.3318,-122.0312"))
        vm.actionDispatcher.setGeolocationProvider(provider)
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let displayAction = try XCTUnwrap(vm.renderedRoot?.body?.layers?.first?.action)
        await vm.actionDispatcher.execute(displayAction)
        let coordLabel = try XCTUnwrap(vm.renderedRoot?.body?.sections?.first?.items?.first)
        XCTAssertEqual(coordLabel.type, "label")
        XCTAssertEqual(coordLabel.text, "37.3318,-122.0312")

        let mapAction = try XCTUnwrap(vm.renderedRoot?.body?.layers?.last?.action)
        await vm.actionDispatcher.execute(mapAction)
        let map = try XCTUnwrap(vm.renderedRoot?.body?.sections?.first?.items?.first)
        XCTAssertEqual(map.type, "map")
        XCTAssertEqual(map.region?.coord, "37.3318,-122.0312")
        XCTAssertEqual(provider.requestCount, 2)
    }

    func testJasonpediaVisionFixtureShowsUnsupportedCameraBackgroundFallback() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/action/vision/index.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let body = try XCTUnwrap(vm.renderedRoot?.body)
        XCTAssertEqual(body.background?.dictionary?["type"]?.string, "camera")
        let label = try XCTUnwrap(body.sections?.first?.items?.first?.components?.first)
        XCTAssertEqual(label.text, "Scanning...")
        XCTAssertEqual(vm.alertConfig?.title, "Not implemented yet")
        XCTAssertEqual(
            vm.alertConfig?.description,
            "Camera-backed vision scanning is recognized, but this iOS renderer does not implement the live camera background or barcode scanner yet."
        )
    }

    func testJasonpediaMapComponentFixtureSelectsMapRendererPath() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/view/component/map/index.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let sections = try XCTUnwrap(vm.renderedRoot?.body?.sections)
        let headerMap = try XCTUnwrap(sections.first?.header?.components?.last)
        let regionMap = try XCTUnwrap(sections[1].items?.first)
        let pinnedMap = try XCTUnwrap(sections[2].items?.first)

        XCTAssertEqual(headerMap.type, "map")
        XCTAssertEqual(regionMap.type, "map")
        XCTAssertEqual(pinnedMap.type, "map")
        XCTAssertTrue(ComponentView.knownComponentTypes.contains("map"))
        XCTAssertEqual(regionMap.region?.coord, "40.7197614,-73.9909211")
        XCTAssertEqual(regionMap.region?.width?.string, "200")
        XCTAssertEqual(regionMap.region?.height?.string, "200")
        XCTAssertEqual(pinnedMap.pins?.first?.title, "This is a pin")
        XCTAssertEqual(pinnedMap.pins?.first?.description, "It really is.")
        XCTAssertTrue(pinnedMap.pins?.first?.style?.isSelectedAnnotation == true)
        XCTAssertEqual(MapComponent.annotations(from: pinnedMap.pins).count, 1)
    }

    func testJasonpediaDynamicLayersFixtureRendersInitialMarioLayer() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/view/layer/dynamic.json"))
        await vm.load()

        XCTAssertEqual(vm.loadState, .loaded)
        let body = try XCTUnwrap(vm.renderedRoot?.body)
        let layers = try XCTUnwrap(body.layers)
        let mario = try XCTUnwrap(layers.last)

        XCTAssertEqual(layers.count, 5)
        XCTAssertEqual(body.style?.background, "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/assets/mariobackground.jpg")
        XCTAssertEqual(mario.type, "image")
        XCTAssertEqual(mario.style?.width?.string, "86")
        XCTAssertEqual(mario.style?.height?.string, "175")
        XCTAssertEqual(mario.style?.bottom?.string, "70")
    }

    func testJasonpediaDynamicLayersTriggerKeepsMarioStyleRenderable() async throws {
        let vm = JasonetteViewModel(document: try loadJasonpediaDocument("Jasonpedia/view/layer/dynamic.json"))
        await vm.load()
        let draggableAction = try XCTUnwrap(vm.renderedRoot?.body?.layers?[1].action)

        await vm.actionDispatcher.execute(draggableAction)

        let mario = try XCTUnwrap(vm.renderedRoot?.body?.layers?.last)
        XCTAssertEqual(mario.style?.width?.string, "86")
        XCTAssertTrue(mario.style?.isMoveEnabled == true)
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

    func testBodyBackgroundRGBAColorFlowsThrough() async {
        let doc = makeDocument([
            "$jason": [
                "head": ["title": "BG RGBA"],
                "body": [
                    "background": "rgba(10,20,30,0.5)",
                    "sections": [
                        ["items": [["type": "label", "text": "RGBA bg"]]]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertEqual(vm.renderedRoot?.body?.background?.string, "rgba(10,20,30,0.5)")
    }

    func testBodyBackgroundHex8ColorFlowsThrough() async {
        let doc = makeDocument([
            "$jason": [
                "head": ["title": "BG Hex8"],
                "body": [
                    "background": "#112233cc",
                    "sections": [
                        ["items": [["type": "label", "text": "Hex8 bg"]]]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertEqual(vm.renderedRoot?.body?.background?.string, "#112233cc")
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
