import XCTest
@testable import Jasonette

final class ExpressionParserTests: XCTestCase {
    private func eval(_ expr: String, context: [String: Any] = [:]) -> Any? {
        ExpressionEvaluator.evaluate(expr, context: context)
    }

    // MARK: - Literals

    func testNumberLiteral() {
        XCTAssertEqual(eval("42") as? Int, 42)
    }

    func testFloatLiteral() {
        guard let result = eval("3.14") as? Double else {
            XCTFail("Expected Double")
            return
        }
        XCTAssertEqual(result, 3.14, accuracy: 0.001)
    }

    func testStringLiteral() {
        XCTAssertEqual(eval("'hello'") as? String, "hello")
    }

    func testDoubleQuoteString() {
        XCTAssertEqual(eval("\"world\"") as? String, "world")
    }

    func testBoolTrue() {
        XCTAssertEqual(eval("true") as? Bool, true)
    }

    func testBoolFalse() {
        XCTAssertEqual(eval("false") as? Bool, false)
    }

    func testNull() {
        let result = eval("null")
        XCTAssertTrue(result is NSNull)
    }

    func testUndefined() {
        let result = eval("undefined")
        XCTAssertTrue(result is NSNull)
    }

    // MARK: - Arithmetic

    func testAddition() {
        XCTAssertEqual(eval("2 + 3") as? Int, 5)
    }

    func testSubtraction() {
        XCTAssertEqual(eval("10 - 4") as? Int, 6)
    }

    func testMultiplication() {
        XCTAssertEqual(eval("3 * 7") as? Int, 21)
    }

    func testDivision() {
        XCTAssertEqual(eval("15 / 3") as? Int, 5)
    }

    func testModulo() {
        XCTAssertEqual(eval("10 % 3") as? Int, 1)
    }

    // MARK: - Comparison

    func testLessThan() {
        XCTAssertEqual(eval("3 < 5") as? Bool, true)
    }

    func testGreaterThan() {
        XCTAssertEqual(eval("5 > 3") as? Bool, true)
    }

    func testEquality() {
        XCTAssertEqual(eval("5 == 5") as? Bool, true)
    }

    func testInequality() {
        XCTAssertEqual(eval("5 != 3") as? Bool, true)
    }

    // MARK: - Logical

    func testLogicalAnd() {
        XCTAssertEqual(eval("true && true") as? Bool, true)
    }

    func testLogicalOr() {
        XCTAssertEqual(eval("false || true") as? Bool, true)
    }

    func testLogicalNot() {
        XCTAssertEqual(eval("!false") as? Bool, true)
    }

    // MARK: - Ternary

    func testTernary() {
        XCTAssertEqual(eval("true ? 'yes' : 'no'") as? String, "yes")
    }

    func testTernaryFalse() {
        XCTAssertEqual(eval("false ? 'yes' : 'no'") as? String, "no")
    }

    // MARK: - Member access

    func testMemberAccess() {
        XCTAssertEqual(eval("user.name", context: ["user": ["name": "Bob"]]) as? String, "Bob")
    }

    func testNestedMember() {
        let ctx: [String: Any] = ["a": ["b": ["c": 99]]]
        XCTAssertEqual(eval("a.b.c", context: ctx) as? Int, 99)
    }

    // MARK: - Array access

    func testArrayLiteral() {
        let result = eval("[1, 2, 3]")
        guard let arr = result as? [Any] else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr.count, 3)
    }

    // MARK: - In operator

    func testInOperator() {
        let result = eval("'name' in obj", context: ["obj": ["name": "test"]])
        XCTAssertEqual(result as? Bool, true)
    }

    // MARK: - Typeof

    func testTypeof() {
        XCTAssertEqual(eval("typeof 'hello'") as? String, "string")
        XCTAssertEqual(eval("typeof 42") as? String, "number")
        XCTAssertEqual(eval("typeof true") as? String, "boolean")
    }

    // MARK: - Safe function calls

    func testParseInt() {
        XCTAssertEqual(eval("parseInt('42')") as? Int, 42)
    }

    func testMathFloor() {
        XCTAssertEqual(eval("Math.floor(3.7)") as? Int, 3)
    }

    // MARK: - Security

    func testBlockedProperty() {
        let result = eval("obj.__proto__", context: ["obj": ["key": "val"]])
        XCTAssertNil(result)
    }

    func testBlockedConstructor() {
        let result = eval("obj.constructor", context: ["obj": ["key": "val"]])
        XCTAssertNil(result)
    }
}
