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

    func testEachWithObjectItemsExposesFieldsAsDirectIdentifiers() {
        let template: [[String: Any]] = [
            [
                "{{#each users}}": [
                    "type": "label",
                    "text": "{{name}}"
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

    func testObjectFormItemsDirectiveRendersArrayAndNestedComponents() throws {
        let template: [String: Any] = [
            "sections": [
                [
                    "items": [
                        "{{#each entries}}": [
                            "type": "vertical",
                            "href": ["url": "{{url}}"],
                            "components": [
                                ["type": "label", "text": "{{title}}"],
                                ["type": "label", "text": "{{description}}"]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        let entries: [[String: Any]] = [
            ["title": "Inline Data", "description": "Render inline data", "url": "https://example.com/inline.json"],
            ["title": "#each", "description": "Loop through arrays", "url": "https://example.com/each.json"]
        ]

        let result = TemplateEngine.render(template, context: ["entries": entries])
        let data = try JSONSerialization.data(withJSONObject: result)
        let body = try JSONDecoder().decode(JasonBody.self, from: data)

        let items = try XCTUnwrap(body.sections?.first?.items)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].type, "vertical")
        XCTAssertEqual(items[0].href?.url, "https://example.com/inline.json")
        XCTAssertEqual(items[0].components?[0].text, "Inline Data")
        XCTAssertEqual(items[0].components?[1].text, "Render inline data")
        XCTAssertEqual(items[1].href?.url, "https://example.com/each.json")
        XCTAssertEqual(items[1].components?[0].text, "#each")
        XCTAssertEqual(items[1].components?[1].text, "Loop through arrays")
    }

    func testObjectFormItemsDirectiveWithNonArrayDataProducesEmptyItems() throws {
        let template: [String: Any] = [
            "sections": [
                [
                    "items": [
                        "{{#each missingEntries}}": [
                            "type": "vertical",
                            "components": [["type": "label", "text": "Should not render"]]
                        ]
                    ]
                ]
            ]
        ]

        let result = TemplateEngine.render(template, context: ["missingEntries": "not an array"])
        let data = try JSONSerialization.data(withJSONObject: result)
        let body = try JSONDecoder().decode(JasonBody.self, from: data)

        XCTAssertEqual(body.sections?.first?.items?.count, 0)
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

    // MARK: - Multiple expressions

    func testMultipleExpressionsInOneString() {
        let template: Any = "{{first}} {{last}}"
        let result = TemplateEngine.render(template, context: ["first": "John", "last": "Doe"])
        XCTAssertEqual(result as? String, "John Doe")
    }

    func testMultipleExpressionsWithStaticText() {
        let template: Any = "Hello {{name}}, you have {{count}} messages"
        let result = TemplateEngine.render(template, context: ["name": "Alice", "count": 5])
        XCTAssertEqual(result as? String, "Hello Alice, you have 5 messages")
    }

    // MARK: - Fast-path (no {{ in string)

    func testFastPathPlainString() {
        let result = TemplateEngine.render("plain text", context: ["x": "ignored"])
        XCTAssertEqual(result as? String, "plain text")
    }

    func testFastPathEmptyString() {
        let result = TemplateEngine.render("", context: ["x": "ignored"])
        XCTAssertEqual(result as? String, "")
    }

    // MARK: - #if with #else

    func testIfElseTakesElseBranch() {
        let template: [[String: Any]] = [
            [
                "{{#if show}}": ["type": "label", "text": "Visible"],
                "{{#else}}": ["type": "label", "text": "Hidden"]
            ]
        ]
        let result = TemplateEngine.render(template, context: ["show": false])
        guard let arr = result as? [[String: Any]] else {
            XCTFail("Expected array"); return
        }
        XCTAssertEqual(arr.count, 1)
        XCTAssertEqual(arr[0]["text"] as? String, "Hidden")
    }

    func testIfElseTakesThenBranch() {
        let template: [[String: Any]] = [
            [
                "{{#if show}}": ["type": "label", "text": "Visible"],
                "{{#else}}": ["type": "label", "text": "Hidden"]
            ]
        ]
        let result = TemplateEngine.render(template, context: ["show": true])
        guard let arr = result as? [[String: Any]] else {
            XCTFail("Expected array"); return
        }
        XCTAssertEqual(arr.count, 1)
        XCTAssertEqual(arr[0]["text"] as? String, "Visible")
    }

    // MARK: - #each edge cases

    func testEachWithEmptyArrayProducesNoItems() {
        let template: [[String: Any]] = [
            ["{{#each items}}": ["type": "label", "text": "{{$jason}}"]]
        ]
        let result = TemplateEngine.render(template, context: ["items": [Any]()])
        guard let arr = result as? [Any] else {
            XCTFail("Expected array"); return
        }
        XCTAssertEqual(arr.count, 0)
    }

    func testEachWithNonArrayProducesEmpty() {
        let template: [[String: Any]] = [
            ["{{#each notAnArray}}": ["type": "label"]]
        ]
        let result = TemplateEngine.render(template, context: ["notAnArray": "string"])
        guard let arr = result as? [Any] else {
            XCTFail("Expected array"); return
        }
        XCTAssertEqual(arr.count, 0)
    }

    func testEachRootVariablePreservesOuterJason() {
        let template: [[String: Any]] = [
            [
                "{{#each items}}": ["text": "{{$root}}"]
            ]
        ]
        let context: [String: Any] = [
            "$jason": "outer",
            "items": ["a", "b"]
        ]
        let result = TemplateEngine.render(template, context: context)
        guard let arr = result as? [[String: Any]] else {
            XCTFail("Expected array"); return
        }
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr[0]["text"] as? String, "outer")
    }

    // MARK: - Depth guard

    func testDepthGuardDoesNotCrashOnDeeplyNested() {
        // 25 levels deep — exceeds maxDepth=20, should return template as-is without crashing
        var template: Any = "{{name}}"
        for i in 0..<25 {
            template = ["level\(i)": template]
        }
        let result = TemplateEngine.render(template, context: ["name": "Alice"])
        XCTAssertNotNil(result)
    }

    // MARK: - AnyCodable-wrapped data

    func testAnyCodableWrappedContextProducesOutput() {
        // Verify TemplateEngine works with plain context values (post-unwrap).
        // AnyCodable.unwrapped converts wrappers to native types before TemplateEngine runs.
        let template: [String: Any] = ["text": "{{greeting}}"]
        let result = TemplateEngine.render(template, context: ["greeting": "Hello"])
        guard let dict = result as? [String: Any] else {
            XCTFail("Expected dictionary"); return
        }
        XCTAssertEqual(dict["text"] as? String, "Hello")
    }

    // MARK: - Object directive rendering

    func testIfDirectiveInObject() {
        // #if inside an object (not array) — returns rendered template or empty array
        let template: [String: Any] = [
            "{{#if show}}": ["type": "label", "text": "Shown"]
        ]
        let result = TemplateEngine.render(template, context: ["show": true])
        // When used in object context, directive result is the rendered template
        XCTAssertNotNil(result)
    }

    func testMissingVariableRendersEmpty() {
        let template: Any = "{{missing}}"
        let result = TemplateEngine.render(template, context: [:])
        // Missing variable evaluates to nil → empty string
        XCTAssertEqual(result as? String, "")
    }
}
