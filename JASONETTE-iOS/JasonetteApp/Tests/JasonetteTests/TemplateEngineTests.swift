import XCTest
@testable import Jasonette

final class TemplateEngineTests: XCTestCase {
    // MARK: - String interpolation

    func testSimpleInterpolation() {
        let template: Any = "Hello {{name}}"
        let result = TemplateEngine.render(template, context: ["name": "World"])
        XCTAssertEqual(result as? String, "Hello World")
    }

    func testSingleExpression() {
        let template: Any = "{{count}}"
        let result = TemplateEngine.render(template, context: ["count": 42])
        // Single expression returns typed value
        XCTAssertEqual(result as? Int, 42)
    }

    func testNestedAccess() {
        let template: Any = "{{user.name}}"
        let result = TemplateEngine.render(template, context: ["user": ["name": "Alice"]])
        XCTAssertEqual(result as? String, "Alice")
    }

    func testArithmeticExpression() {
        let template: Any = "{{a + b}}"
        let result = TemplateEngine.render(template, context: ["a": 10, "b": 20])
        XCTAssertEqual(result as? Int, 30)
    }

    func testTernaryExpression() {
        let template: Any = "{{active ? 'Yes' : 'No'}}"
        let result = TemplateEngine.render(template, context: ["active": true])
        XCTAssertEqual(result as? String, "Yes")
    }

    // MARK: - #each

    func testEachDirective() {
        let template: [[String: Any]] = [
            [
                "{{#each items}}": [
                    "type": "label",
                    "text": "{{$jason}}"
                ]
            ]
        ]
        let result = TemplateEngine.render(template, context: ["items": ["a", "b", "c"]])
        guard let arr = result as? [[String: Any]] else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr.count, 3)
        XCTAssertEqual(arr[0]["text"] as? String, "a")
        XCTAssertEqual(arr[1]["text"] as? String, "b")
        XCTAssertEqual(arr[2]["text"] as? String, "c")
    }

    func testEachWithIndex() {
        let template: [[String: Any]] = [
            [
                "{{#each items}}": [
                    "text": "{{$index}}"
                ]
            ]
        ]
        let result = TemplateEngine.render(template, context: ["items": ["x", "y"]])
        guard let arr = result as? [[String: Any]] else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr[0]["text"] as? Int, 0)
        XCTAssertEqual(arr[1]["text"] as? Int, 1)
    }

    func testEachWithObjectItems() {
        let template: [[String: Any]] = [
            [
                "{{#each users}}": [
                    "type": "label",
                    "text": "{{$jason.name}}"
                ]
            ]
        ]
        let users: [[String: Any]] = [
            ["name": "Alice"],
            ["name": "Bob"]
        ]
        let result = TemplateEngine.render(template, context: ["users": users])
        guard let arr = result as? [[String: Any]] else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr[0]["text"] as? String, "Alice")
        XCTAssertEqual(arr[1]["text"] as? String, "Bob")
    }

    // MARK: - #if

    func testIfTrue() {
        let template: [[String: Any]] = [
            [
                "{{#if show}}": [
                    "type": "label",
                    "text": "Visible"
                ]
            ]
        ]
        let result = TemplateEngine.render(template, context: ["show": true])
        guard let arr = result as? [[String: Any]] else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr.count, 1)
        XCTAssertEqual(arr[0]["text"] as? String, "Visible")
    }

    func testIfFalse() {
        let template: [[String: Any]] = [
            [
                "{{#if show}}": [
                    "type": "label",
                    "text": "Visible"
                ]
            ]
        ]
        let result = TemplateEngine.render(template, context: ["show": false])
        guard let arr = result as? [Any] else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr.count, 0)
    }

    // MARK: - Dictionary rendering

    func testDictionaryRendering() {
        let template: [String: Any] = [
            "type": "label",
            "text": "{{greeting}}"
        ]
        let result = TemplateEngine.render(template, context: ["greeting": "Hi"])
        guard let dict = result as? [String: Any] else {
            XCTFail("Expected dictionary")
            return
        }
        XCTAssertEqual(dict["type"] as? String, "label")
        XCTAssertEqual(dict["text"] as? String, "Hi")
    }

    // MARK: - Passthrough

    func testNonTemplatePassthrough() {
        let result = TemplateEngine.render(42, context: [:])
        XCTAssertEqual(result as? Int, 42)
    }

    func testBoolPassthrough() {
        let result = TemplateEngine.render(true, context: [:])
        XCTAssertEqual(result as? Bool, true)
    }

    // MARK: - Expression parser

    func testComparison() {
        let template: Any = "{{a > b}}"
        let result = TemplateEngine.render(template, context: ["a": 10, "b": 5])
        XCTAssertEqual(result as? Bool, true)
    }

    func testLogicalAnd() {
        let template: Any = "{{a && b}}"
        let result = TemplateEngine.render(template, context: ["a": true, "b": false])
        // In JS, a && b returns the first falsy value
        XCTAssertEqual(result as? Bool, false)
    }

    func testStringConcatenation() {
        let template: Any = "{{first + ' ' + last}}"
        let result = TemplateEngine.render(template, context: ["first": "John", "last": "Doe"])
        XCTAssertEqual(result as? String, "John Doe")
    }
}
