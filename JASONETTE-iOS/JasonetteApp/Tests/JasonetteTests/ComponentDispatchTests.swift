import XCTest
@testable import Jasonette

final class ComponentDispatchTests: XCTestCase {

    // MARK: - Helpers

    private func decodeComponent(_ json: [String: Any]) -> JasonComponent {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonComponent.self, from: data)
    }

    // MARK: - Label

    func testLabelHasText() {
        let component = decodeComponent(["type": "label", "text": "Hello World"])
        XCTAssertEqual(component.type, "label")
        XCTAssertEqual(component.text, "Hello World")
    }

    // MARK: - Image

    func testImageHasURL() {
        let component = decodeComponent(["type": "image", "url": "https://example.com/img.png"])
        XCTAssertEqual(component.type, "image")
        XCTAssertEqual(component.url, "https://example.com/img.png")
    }

    // MARK: - Button

    func testButtonHasTextAndURL() {
        let component = decodeComponent([
            "type": "button",
            "text": "Click Me",
            "url": "https://example.com/icon.png"
        ])
        XCTAssertEqual(component.type, "button")
        XCTAssertEqual(component.text, "Click Me")
        XCTAssertEqual(component.url, "https://example.com/icon.png")
    }

    // MARK: - TextField

    func testTextFieldHasNamePlaceholderKeyboardValue() {
        let component = decodeComponent([
            "type": "textfield",
            "name": "email",
            "placeholder": "Enter email",
            "keyboard": "email",
            "value": "test@example.com"
        ])
        XCTAssertEqual(component.type, "textfield")
        XCTAssertEqual(component.name, "email")
        XCTAssertEqual(component.placeholder, "Enter email")
        XCTAssertEqual(component.keyboard, "email")
        XCTAssertEqual(component.value?.string, "test@example.com")
        XCTAssertEqual(TextFieldComponent.fieldKind(componentType: component.type, style: component.style), .plain)
    }

    func testTextFieldStyleSecureStringChoosesSecureFieldKind() {
        let component = decodeComponent([
            "type": "textfield",
            "name": "password",
            "placeholder": "Secure field",
            "style": ["secure": "true"]
        ])
        XCTAssertEqual(component.style?.secure?.string, "true")
        XCTAssertTrue(component.style?.isSecureTextEntry == true)
        XCTAssertEqual(TextFieldComponent.fieldKind(componentType: component.type, style: component.style), .secure)
    }

    func testTextFieldStyleSecureBoolChoosesSecureFieldKind() {
        let component = decodeComponent([
            "type": "textfield",
            "name": "password",
            "style": ["secure": true]
        ])
        XCTAssertEqual(component.style?.secure?.bool, true)
        XCTAssertEqual(TextFieldComponent.fieldKind(componentType: component.type, style: component.style), .secure)
    }

    func testSecureComponentTypeChoosesSecureFieldKind() {
        let component = decodeComponent([
            "type": "secure",
            "name": "password",
            "placeholder": "Enter password"
        ])
        XCTAssertEqual(component.type, "secure")
        XCTAssertEqual(TextFieldComponent.fieldKind(componentType: component.type, style: component.style), .secure)
    }

    // MARK: - TextArea

    func testTextAreaHasNamePlaceholder() {
        let component = decodeComponent([
            "type": "textarea",
            "name": "bio",
            "placeholder": "Tell us about yourself"
        ])
        XCTAssertEqual(component.type, "textarea")
        XCTAssertEqual(component.name, "bio")
        XCTAssertEqual(component.placeholder, "Tell us about yourself")
    }

    // MARK: - Slider

    func testSliderHasNameAndDoubleValue() {
        let component = decodeComponent([
            "type": "slider",
            "name": "volume",
            "value": 0.75
        ])
        XCTAssertEqual(component.type, "slider")
        XCTAssertEqual(component.name, "volume")
        XCTAssertEqual(component.value?.double, 0.75)
    }

    // MARK: - Switch

    func testSwitchHasNameAndBoolValue() {
        let component = decodeComponent([
            "type": "switch",
            "name": "notifications",
            "value": true
        ])
        XCTAssertEqual(component.type, "switch")
        XCTAssertEqual(component.name, "notifications")
        XCTAssertEqual(component.value?.bool, true)
    }

    // MARK: - Space

    func testSpaceHasStyleHeight() {
        let component = decodeComponent([
            "type": "space",
            "style": ["height": 20]
        ])
        XCTAssertEqual(component.type, "space")
        XCTAssertNotNil(component.style)
        XCTAssertEqual(component.style?.height?.int, 20)
    }

    // MARK: - Map

    func testMapTypeIsMap() {
        let component = decodeComponent(["type": "map"])
        XCTAssertEqual(component.type, "map")
    }

    // MARK: - HTML

    func testHTMLComponentDecodesTextCSSAndURL() {
        let component = decodeComponent([
            "type": "html",
            "text": "<p>Hello</p>",
            "css": "p{color:red;}",
            "url": "article.html"
        ])
        XCTAssertEqual(component.type, "html")
        XCTAssertEqual(component.text, "<p>Hello</p>")
        XCTAssertEqual(component.css, "p{color:red;}")
        XCTAssertEqual(component.url, "article.html")
    }

    @MainActor
    func testHTMLTypeIsKnownByComponentRegistry() {
        let knownTypes = ComponentView.knownComponentTypes
        XCTAssertTrue(knownTypes.contains("html"))
    }

    @MainActor
    func testHTMLComponentWrapsFragmentWithCSS() {
        let html = HTMLComponent.documentHTML(text: "<p>Hello</p>", css: "p{color:red;}")
        XCTAssertTrue(html.contains("<body><p>Hello</p></body>"))
        XCTAssertTrue(html.contains("p{color:red;}"))
        XCTAssertTrue(html.contains("viewport"))
    }

    @MainActor
    func testHTMLComponentResolvesRelativeURLAgainstDocumentURL() {
        let component = HTMLComponent(
            text: nil,
            css: nil,
            url: "article.html",
            documentURL: URL(string: "https://example.com/docs/index.json")
        )
        XCTAssertEqual(component.resolvedURL?.absoluteString, "https://example.com/docs/article.html")
    }

    @MainActor
    func testHTMLComponentRejectsDisallowedURLScheme() {
        let component = HTMLComponent(
            text: nil,
            css: nil,
            url: "javascript:alert(1)",
            documentURL: URL(string: "https://example.com/docs/index.json")
        )
        XCTAssertNil(component.resolvedURL)
    }

    // MARK: - Unknown type

    func testUnknownTypePreserved() {
        let component = decodeComponent(["type": "foo"])
        XCTAssertEqual(component.type, "foo")
    }

    // MARK: - Layout types

    func testVerticalHasComponents() {
        let component = decodeComponent([
            "type": "vertical",
            "components": [
                ["type": "label", "text": "First"],
                ["type": "label", "text": "Second"]
            ]
        ])
        XCTAssertEqual(component.type, "vertical")
        XCTAssertEqual(component.components?.count, 2)
        XCTAssertEqual(component.components?.first?.text, "First")
        XCTAssertEqual(component.components?.last?.text, "Second")
    }

    func testHorizontalHasComponents() {
        let component = decodeComponent([
            "type": "horizontal",
            "components": [
                ["type": "image", "url": "https://example.com/a.png"],
                ["type": "label", "text": "Caption"]
            ]
        ])
        XCTAssertEqual(component.type, "horizontal")
        XCTAssertEqual(component.components?.count, 2)
        XCTAssertEqual(component.components?.first?.url, "https://example.com/a.png")
        XCTAssertEqual(component.components?.last?.text, "Caption")
    }

    func testVerticalWithEmptyComponents() {
        let component = decodeComponent(["type": "vertical", "components": []])
        XCTAssertEqual(component.type, "vertical")
        XCTAssertEqual(component.components?.count, 0)
    }

    // MARK: - href wrapping

    func testComponentWithHref() {
        let component = decodeComponent([
            "type": "label",
            "text": "Tap me",
            "href": ["url": "https://example.com", "view": "push"]
        ])
        XCTAssertNotNil(component.href)
        XCTAssertEqual(component.href?.url, "https://example.com")
        XCTAssertEqual(component.href?.view, "push")
    }

    func testComponentWithHrefTransition() {
        let component = decodeComponent([
            "type": "label",
            "text": "Slide",
            "href": ["url": "https://example.com", "view": "push", "transition": "slide"]
        ])
        XCTAssertEqual(component.href?.transition, "slide")
    }

    func testComponentWithBackHref() {
        let component = decodeComponent([
            "type": "label",
            "text": "Back",
            "href": ["view": "$back"]
        ])
        XCTAssertEqual(component.href?.view, "$back")
        XCTAssertNil(component.href?.url)
    }

    // MARK: - action wrapping

    func testComponentWithAction() {
        let component = decodeComponent([
            "type": "button",
            "text": "Submit",
            "action": ["type": "$set", "options": ["submitted": true]]
        ])
        XCTAssertNotNil(component.action)
        XCTAssertEqual(component.action?.type, "$set")
    }

    func testComponentWithActionSuccessChain() {
        let component = decodeComponent([
            "type": "button",
            "text": "Chain",
            "action": [
                "type": "$set",
                "options": ["step": "first"],
                "success": ["type": "$set", "options": ["step": "second"]]
            ]
        ])
        XCTAssertEqual(component.action?.type, "$set")
        XCTAssertEqual(component.action?.success?.type, "$set")
    }

    // MARK: - class and style fields

    func testComponentWithClass() {
        let component = decodeComponent([
            "type": "label",
            "text": "Styled",
            "class": "primary"
        ])
        XCTAssertEqual(component.class, "primary")
    }

    func testComponentWithStyle() {
        let component = decodeComponent([
            "type": "label",
            "text": "Bold",
            "style": ["size": 18, "color": "#333333"]
        ])
        XCTAssertEqual(component.style?.size?.int, 18)
        XCTAssertEqual(component.style?.color, "#333333")
    }

    func testComponentStylePaddingFields() {
        let component = decodeComponent([
            "type": "space",
            "style": [
                "padding": 10,
                "padding_left": 5,
                "padding_right": 5,
                "padding_top": 8,
                "padding_bottom": 8
            ]
        ])
        XCTAssertEqual(component.style?.padding?.int, 10)
        XCTAssertEqual(component.style?.paddingLeft?.int, 5)
        XCTAssertEqual(component.style?.paddingRight?.int, 5)
        XCTAssertEqual(component.style?.paddingTop?.int, 8)
        XCTAssertEqual(component.style?.paddingBottom?.int, 8)
    }

    func testComponentStyleCornerRadiusAndBorder() {
        let component = decodeComponent([
            "type": "image",
            "url": "https://example.com/img.png",
            "style": [
                "corner_radius": 8,
                "border_width": 1,
                "border_color": "#cccccc"
            ]
        ])
        XCTAssertEqual(component.style?.cornerRadius?.int, 8)
        XCTAssertEqual(component.style?.borderWidth?.int, 1)
        XCTAssertEqual(component.style?.borderColor, "#cccccc")
    }

    // MARK: - nil and minimal components

    func testComponentWithNoType() {
        let component = decodeComponent(["text": "No type"])
        XCTAssertNil(component.type)
        XCTAssertEqual(component.text, "No type")
    }

    func testEmptyComponentDecodesWithoutCrash() {
        let component = decodeComponent([:])
        XCTAssertNil(component.type)
        XCTAssertNil(component.text)
    }

    // MARK: - image field (footer input pattern)

    func testComponentWithImageField() {
        let component = decodeComponent([
            "image": "https://example.com/camera.png",
            "action": ["type": "$media.camera"]
        ])
        XCTAssertEqual(component.image, "https://example.com/camera.png")
        XCTAssertEqual(component.imageURL, "https://example.com/camera.png")
        XCTAssertNil(component.url)
    }

    func testImageURLPrefersURLOverImage() {
        let component = decodeComponent([
            "type": "image",
            "url": "https://example.com/primary.png",
            "image": "https://example.com/fallback.png"
        ])
        XCTAssertEqual(component.imageURL, "https://example.com/primary.png")
    }

    // MARK: - Footer input decoding

    private func decodeFooter(_ json: [String: Any]) -> JasonFooter {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonFooter.self, from: data)
    }

    func testFooterInputDecodesTextfieldProperties() {
        let footer = decodeFooter([
            "input": [
                "name": "message",
                "placeholder": "Say something..."
            ]
        ])
        XCTAssertNotNil(footer.input)
        XCTAssertEqual(footer.input?.name, "message")
        XCTAssertEqual(footer.input?.placeholder, "Say something...")
    }

    func testFooterInputDecodesLeftAndRightComponents() {
        let footer = decodeFooter([
            "input": [
                "name": "message",
                "placeholder": "Type...",
                "left": [
                    "image": "https://example.com/cam.png",
                    "action": ["type": "$media.camera"]
                ],
                "right": [
                    "text": "Send",
                    "action": ["type": "$util.alert"]
                ]
            ]
        ])
        XCTAssertNotNil(footer.input?.left)
        XCTAssertEqual(footer.input?.left?.image, "https://example.com/cam.png")
        XCTAssertEqual(footer.input?.left?.imageURL, "https://example.com/cam.png")
        XCTAssertEqual(footer.input?.left?.action?.type, "$media.camera")

        XCTAssertNotNil(footer.input?.right)
        XCTAssertEqual(footer.input?.right?.text, "Send")
        XCTAssertEqual(footer.input?.right?.action?.type, "$util.alert")
    }

    func testFooterWithBothTabsAndInput() {
        let footer = decodeFooter([
            "tabs": [
                "items": [
                    ["type": "label", "text": "Tab1"]
                ]
            ],
            "input": [
                "name": "msg",
                "placeholder": "Hi"
            ]
        ])
        // Both decode — the view layer decides precedence (tabs win)
        XCTAssertNotNil(footer.tabs)
        XCTAssertNotNil(footer.input)
        XCTAssertEqual(footer.tabs?.items?.count, 1)
        XCTAssertEqual(footer.input?.name, "msg")
    }

    func testFooterInputTextfieldNameAccessibleForStateBinding() {
        let footer = decodeFooter([
            "input": [
                "name": "chat_message",
                "placeholder": "Enter text"
            ]
        ])
        // The name field is what StateManager uses as the binding key
        let name = footer.input?.name ?? ""
        XCTAssertEqual(name, "chat_message")
        XCTAssertFalse(name.isEmpty, "Name must be non-empty for state binding")
    }

    func testFooterInputWithOnlyTextfield() {
        let footer = decodeFooter([
            "input": [
                "name": "query",
                "placeholder": "Search..."
            ]
        ])
        XCTAssertNotNil(footer.input)
        XCTAssertNil(footer.input?.left)
        XCTAssertNil(footer.input?.right)
        XCTAssertEqual(footer.input?.name, "query")
        XCTAssertEqual(footer.input?.placeholder, "Search...")
    }
}
