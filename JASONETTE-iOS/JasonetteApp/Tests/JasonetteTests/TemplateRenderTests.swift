import XCTest
@testable import Jasonette

final class TemplateRenderTests: XCTestCase {

    // MARK: - Helpers

    private func makeDocument(_ json: [String: Any]) -> JasonDocument {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonDocument.self, from: data)
    }

    // MARK: - JasonTemplates decoding

    func testJasonTemplatesDecodesArbitraryNamedTemplates() throws {
        let json: [String: Any] = [
            "$jason": [
                "head": [
                    "title": "Multi",
                    "templates": [
                        "body": ["sections": [["items": [["type": "label", "text": "Default"]]]]],
                        "horizontal": ["sections": [["items": [["type": "label", "text": "Horiz"]]]]],
                        "custom": ["sections": [["items": [["type": "label", "text": "Custom"]]]]]
                    ]
                ]
            ]
        ]
        let doc = makeDocument(json)
        let templates = doc.jason.head?.templates

        XCTAssertNotNil(templates)
        XCTAssertNotNil(templates?.body)
        XCTAssertNotNil(templates?["horizontal"])
        XCTAssertNotNil(templates?["custom"])
    }

    func testJasonTemplatesSubscriptReturnsNilForMissing() throws {
        let json: [String: Any] = [
            "$jason": [
                "head": [
                    "templates": [
                        "body": ["sections": []]
                    ]
                ]
            ]
        ]
        let doc = makeDocument(json)
        XCTAssertNil(doc.jason.head?.templates?["nonexistent"])
    }

    func testJasonTemplatesBodyConvenienceProperty() throws {
        let json: [String: Any] = [
            "$jason": [
                "head": [
                    "templates": [
                        "body": ["sections": [["items": [["type": "label", "text": "Body"]]]]]
                    ]
                ]
            ]
        ]
        let doc = makeDocument(json)
        let body = doc.jason.head?.templates?.body
        XCTAssertNotNil(body)
    }

    // MARK: - Template rendered as JasonBody (not JasonRoot)

    @MainActor
    func testTemplateRendersAsBodyNotRoot() async {
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "Template Body",
                    "data": ["name": "Test"],
                    "templates": [
                        "body": [
                            "sections": [
                                ["items": [["type": "label", "text": "{{name}}"]]]
                            ]
                        ]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertNotNil(vm.renderedRoot?.body)
        XCTAssertEqual(vm.renderedRoot?.body?.sections?.count, 1)
        // Template expression should be resolved
        XCTAssertEqual(vm.renderedRoot?.body?.sections?.first?.items?.first?.text, "Test")
        // Head should be preserved
        XCTAssertEqual(vm.renderedRoot?.head?.title, "Template Body")
    }

    @MainActor
    func testTemplateOnlyDocument_NoTopLevelBody() async {
        // Document with templates but NO top-level body — the common case for templates.json
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "Templates Only",
                    "data": ["greeting": "Hello"],
                    "templates": [
                        "body": [
                            "sections": [
                                ["items": [["type": "label", "text": "{{greeting}}"]]]
                            ]
                        ]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertNotNil(vm.renderedRoot?.body)
        XCTAssertEqual(vm.renderedRoot?.body?.sections?.first?.items?.first?.text, "Hello")
    }

    // MARK: - $render action with template switching

    @MainActor
    func testRenderActionWithTemplateSwitches() async {
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "Switch",
                    "data": ["name": "Bart"],
                    "templates": [
                        "body": [
                            "sections": [
                                ["items": [["type": "label", "text": "Vertical: {{name}}"]]]
                            ]
                        ],
                        "horizontal": [
                            "sections": [
                                ["items": [["type": "label", "text": "Horizontal: {{name}}"]]]
                            ]
                        ]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()

        // Default template is "body"
        XCTAssertEqual(vm.renderedRoot?.body?.sections?.first?.items?.first?.text, "Vertical: Bart")

        // Switch to "horizontal" template via $render action
        let switchAction = JasonAction()
        switchAction.type = "$render"
        switchAction.options = ["template": AnyCodable("horizontal")]
        vm.handleAction(switchAction)

        // Give the async action time to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.renderedRoot?.body?.sections?.first?.items?.first?.text, "Horizontal: Bart")
    }

    @MainActor
    func testRenderActionWithoutTemplateReRendersCurrentTemplate() async {
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "ReRender",
                    "data": ["count": 1],
                    "templates": [
                        "body": [
                            "sections": [
                                ["items": [["type": "label", "text": "Count: {{count}}"]]]
                            ]
                        ]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.renderedRoot?.body?.sections?.first?.items?.first?.text, "Count: 1")

        // $render without template option re-renders current template
        let renderAction = JasonAction()
        renderAction.type = "$render"
        vm.handleAction(renderAction)

        try? await Task.sleep(nanoseconds: 100_000_000)

        // Should still show the body template (re-rendered)
        XCTAssertNotNil(vm.renderedRoot?.body)
    }

    @MainActor
    func testRenderActionUnknownTemplateFallsBack() async {
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "Unknown",
                    "data": ["name": "Test"],
                    "templates": [
                        "body": [
                            "sections": [
                                ["items": [["type": "label", "text": "{{name}}"]]]
                            ]
                        ]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()

        // Try to switch to a template that doesn't exist
        let switchAction = JasonAction()
        switchAction.type = "$render"
        switchAction.options = ["template": AnyCodable("nonexistent")]
        vm.handleAction(switchAction)

        try? await Task.sleep(nanoseconds: 100_000_000)

        // Should still have content (either kept current or fell back to raw doc)
        XCTAssertNotNil(vm.renderedRoot)
    }

    // MARK: - $render action handler on ActionDispatcher

    @MainActor
    func testRenderActionCallsRenderHandler() async {
        let suiteName = "RenderHandlerTest"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let stateManager = StateManager(defaults: defaults)
        let dispatcher = ActionDispatcher(stateManager: stateManager)

        let expectation = expectation(description: "render handler called")
        var receivedTemplate: String?
        dispatcher.setRenderHandler { templateName in
            receivedTemplate = templateName
            expectation.fulfill()
        }

        let data = try! JSONSerialization.data(withJSONObject: [
            "type": "$render",
            "options": ["template": "horizontal"]
        ])
        let action = try! JSONDecoder().decode(JasonAction.self, from: data)
        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTemplate, "horizontal")

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    func testRenderActionWithoutTemplateCallsHandlerWithNil() async {
        let suiteName = "RenderHandlerNilTest"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let stateManager = StateManager(defaults: defaults)
        let dispatcher = ActionDispatcher(stateManager: stateManager)

        let expectation = expectation(description: "render handler called")
        var receivedTemplate: String? = "sentinel"
        dispatcher.setRenderHandler { templateName in
            receivedTemplate = templateName
            expectation.fulfill()
        }

        let data = try! JSONSerialization.data(withJSONObject: ["type": "$render"] as [String: Any])
        let action = try! JSONDecoder().decode(JasonAction.self, from: data)
        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNil(receivedTemplate)

        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - JasonSection type field

    func testJasonSectionDecodesTypeField() throws {
        let json: [String: Any] = [
            "$jason": [
                "body": [
                    "sections": [
                        ["type": "horizontal", "items": [["type": "label", "text": "A"]]],
                        ["items": [["type": "label", "text": "B"]]]
                    ]
                ]
            ]
        ]
        let doc = makeDocument(json)
        XCTAssertEqual(doc.jason.body?.sections?[0].type, "horizontal")
        XCTAssertNil(doc.jason.body?.sections?[1].type)
    }

    // MARK: - Template with layers

    @MainActor
    func testTemplateWithLayersRendersLayers() async {
        let doc = makeDocument([
            "$jason": [
                "head": [
                    "title": "Layers",
                    "templates": [
                        "body": [
                            "sections": [
                                ["items": [["type": "label", "text": "Content"]]]
                            ],
                            "layers": [
                                ["type": "label", "text": "Floating"]
                            ]
                        ]
                    ]
                ]
            ]
        ])
        let vm = JasonetteViewModel(document: doc)
        await vm.load()
        XCTAssertEqual(vm.loadState, .loaded)
        XCTAssertNotNil(vm.renderedRoot?.body?.layers)
        XCTAssertEqual(vm.renderedRoot?.body?.layers?.count, 1)
        XCTAssertEqual(vm.renderedRoot?.body?.layers?.first?.text, "Floating")
    }

    // MARK: - JasonAction public init

    func testJasonActionCanBeCreatedProgrammatically() {
        let action = JasonAction()
        action.type = "$render"
        action.options = ["template": AnyCodable("horizontal")]
        XCTAssertEqual(action.type, "$render")
        XCTAssertEqual(action.options?["template"]?.string, "horizontal")
    }
}
