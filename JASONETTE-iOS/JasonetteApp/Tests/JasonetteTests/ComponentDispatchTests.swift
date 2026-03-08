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

    // MARK: - Unknown type

    func testUnknownTypePreserved() {
        let component = decodeComponent(["type": "foo"])
        XCTAssertEqual(component.type, "foo")
    }
}
