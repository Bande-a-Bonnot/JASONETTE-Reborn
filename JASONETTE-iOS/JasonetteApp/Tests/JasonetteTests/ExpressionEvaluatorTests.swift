import XCTest
@testable import Jasonette

final class ExpressionEvaluatorTests: XCTestCase {
    private func eval(_ expr: String, context: [String: Any] = [:]) -> Any? {
        ExpressionEvaluator.evaluate(expr, context: context)
    }

    // MARK: - isTruthy

    func testIsTruthyNil() {
        XCTAssertFalse(ExpressionEvaluator.isTruthy(nil))
    }

    func testIsTruthyNSNull() {
        XCTAssertFalse(ExpressionEvaluator.isTruthy(NSNull()))
    }

    func testIsTruthyZeroInt() {
        XCTAssertFalse(ExpressionEvaluator.isTruthy(0))
    }

    func testIsTruthyZeroDouble() {
        XCTAssertFalse(ExpressionEvaluator.isTruthy(0.0))
    }

    func testIsTruthyNonZeroInt() {
        XCTAssertTrue(ExpressionEvaluator.isTruthy(1))
    }

    func testIsTruthyEmptyString() {
        XCTAssertFalse(ExpressionEvaluator.isTruthy(""))
    }

    func testIsTruthyNonEmptyString() {
        XCTAssertTrue(ExpressionEvaluator.isTruthy("hello"))
    }

    func testIsTruthyEmptyArray() {
        XCTAssertFalse(ExpressionEvaluator.isTruthy([Any]()))
    }

    func testIsTruthyNonEmptyArray() {
        XCTAssertTrue(ExpressionEvaluator.isTruthy([1, 2] as [Any]))
    }

    func testIsTruthyBoolTrue() {
        XCTAssertTrue(ExpressionEvaluator.isTruthy(true))
    }

    func testIsTruthyBoolFalse() {
        XCTAssertFalse(ExpressionEvaluator.isTruthy(false))
    }

    // MARK: - length property

    func testArrayLength() {
        XCTAssertEqual(eval("items.length", context: ["items": [1, 2, 3]]) as? Int, 3)
    }

    func testEmptyArrayLength() {
        XCTAssertEqual(eval("items.length", context: ["items": [Any]()]) as? Int, 0)
    }

    func testStringLength() {
        XCTAssertEqual(eval("word.length", context: ["word": "hello"]) as? Int, 5)
    }

    // MARK: - Computed member access

    func testComputedArrayFirstElement() {
        XCTAssertEqual(eval("items[0]", context: ["items": ["a", "b", "c"]]) as? String, "a")
    }

    func testComputedArrayLastElement() {
        XCTAssertEqual(eval("items[2]", context: ["items": [10, 20, 30]]) as? Int, 30)
    }

    func testComputedDictStringKey() {
        XCTAssertEqual(eval("obj['name']", context: ["obj": ["name": "Alice"]]) as? String, "Alice")
    }

    func testComputedOutOfBoundsReturnsNil() {
        XCTAssertNil(eval("items[99]", context: ["items": ["x"]]))
    }

    // MARK: - typeof edge cases

    func testTypeofNull() {
        XCTAssertEqual(eval("typeof null") as? String, "object")
    }

    func testTypeofArray() {
        XCTAssertEqual(eval("typeof items", context: ["items": [1, 2]]) as? String, "object")
    }

    func testTypeofObject() {
        XCTAssertEqual(eval("typeof obj", context: ["obj": ["k": "v"]]) as? String, "object")
    }

    func testTypeofUndefined() {
        XCTAssertEqual(eval("typeof missing") as? String, "undefined")
    }

    // MARK: - this keyword

    func testThisResolvesToJason() {
        XCTAssertEqual(eval("this.name", context: ["$jason": ["name": "Bob"]]) as? String, "Bob")
    }

    func testThisReturnsNilWhenNoJason() {
        XCTAssertNil(eval("this.name", context: [:]))
    }

    // MARK: - Safe functions

    func testArrayIsArrayTrue() {
        XCTAssertEqual(eval("Array.isArray(items)", context: ["items": [1, 2]]) as? Bool, true)
    }

    func testArrayIsArrayFalseForString() {
        XCTAssertEqual(eval("Array.isArray('hello')") as? Bool, false)
    }

    func testMathMin() {
        guard let result = eval("Math.min(3, 1, 2)") as? Double else {
            XCTFail("Expected Double"); return
        }
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func testMathMax() {
        guard let result = eval("Math.max(3, 1, 2)") as? Double else {
            XCTFail("Expected Double"); return
        }
        XCTAssertEqual(result, 3.0, accuracy: 0.001)
    }

    func testMathAbs() {
        guard let result = eval("Math.abs(-5)") as? Double else {
            XCTFail("Expected Double"); return
        }
        XCTAssertEqual(result, 5.0, accuracy: 0.001)
    }

    func testMathCeil() {
        XCTAssertEqual(eval("Math.ceil(3.2)") as? Int, 4)
    }

    func testMathRound() {
        XCTAssertEqual(eval("Math.round(3.7)") as? Int, 4)
    }

    func testMathRoundDown() {
        XCTAssertEqual(eval("Math.round(3.2)") as? Int, 3)
    }

    func testJSONStringifyProducesString() {
        let result = eval("JSON.stringify(obj)", context: ["obj": ["key": "value"]]) as? String
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("key") == true)
        XCTAssertTrue(result?.contains("value") == true)
    }

    func testJSONStringifyOnNonObject() {
        // Non-JSON-object falls back to string interpolation
        let result = eval("JSON.stringify(n)", context: ["n": 42])
        XCTAssertNotNil(result)
    }

    func testStringFunction() {
        XCTAssertEqual(eval("String(42)") as? String, "42")
    }

    func testNumberFunction() {
        guard let result = eval("Number('3.14')") as? Double else {
            XCTFail("Expected Double"); return
        }
        XCTAssertEqual(result, 3.14, accuracy: 0.001)
    }

    func testParseFloat() {
        guard let result = eval("parseFloat('2.71')") as? Double else {
            XCTFail("Expected Double"); return
        }
        XCTAssertEqual(result, 2.71, accuracy: 0.001)
    }

    func testParseInt() {
        XCTAssertEqual(eval("parseInt('42')") as? Int, 42)
    }

    // MARK: - Unary operators

    func testUnaryMinus() {
        guard let result = eval("-n", context: ["n": 5]) as? Double else {
            XCTFail("Expected Double"); return
        }
        XCTAssertEqual(result, -5.0, accuracy: 0.001)
    }

    func testUnaryPlusCoercesString() {
        guard let result = eval("+s", context: ["s": "42"]) as? Double else {
            XCTFail("Expected Double"); return
        }
        XCTAssertEqual(result, 42.0, accuracy: 0.001)
    }

    // MARK: - Arithmetic edge cases

    func testDivisionByZeroReturnsNil() {
        XCTAssertNil(eval("10 / 0"))
    }

    func testModuloByZeroReturnsNil() {
        XCTAssertNil(eval("10 % 0"))
    }

    func testIntegerDivisionPreservesInt() {
        XCTAssertEqual(eval("10 / 2") as? Int, 5)
    }

    func testIntegerModulo() {
        XCTAssertEqual(eval("10 % 3") as? Int, 1)
    }

    // MARK: - In operator

    func testInOperatorKeyPresent() {
        XCTAssertEqual(eval("'name' in obj", context: ["obj": ["name": "test"]]) as? Bool, true)
    }

    func testInOperatorKeyAbsent() {
        XCTAssertEqual(eval("'missing' in obj", context: ["obj": ["name": "test"]]) as? Bool, false)
    }

    func testInOperatorNonStringKeyReturnsFalse() {
        XCTAssertEqual(eval("42 in obj", context: ["obj": ["name": "test"]]) as? Bool, false)
    }

    // MARK: - Short-circuit logic

    func testAndShortCircuitsOnFalsy() {
        // false && expr — should return false without evaluating right side
        XCTAssertEqual(eval("false && missing_fn()") as? Bool, false)
    }

    func testOrShortCircuitsOnTruthy() {
        // true || expr — should return true without evaluating right side
        XCTAssertEqual(eval("true || missing_fn()") as? Bool, true)
    }

    // MARK: - Edge cases

    func testEmptyExpressionReturnsNil() {
        XCTAssertNil(eval(""))
    }

    func testWhitespaceOnlyReturnsNil() {
        XCTAssertNil(eval("   "))
    }

    func testMissingContextKeyReturnsNil() {
        XCTAssertNil(eval("missing_key"))
    }

    func testNullEquality() {
        XCTAssertEqual(eval("null == null") as? Bool, true)
    }

    func testNullInequalityWithString() {
        XCTAssertEqual(eval("null != 'hello'") as? Bool, true)
    }

    func testStringEquality() {
        XCTAssertEqual(eval("name == 'Alice'", context: ["name": "Alice"]) as? Bool, true)
        XCTAssertEqual(eval("name == 'Bob'", context: ["name": "Alice"]) as? Bool, false)
    }
}
