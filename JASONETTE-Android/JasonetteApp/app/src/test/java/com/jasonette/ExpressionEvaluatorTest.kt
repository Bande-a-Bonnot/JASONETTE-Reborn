package com.jasonette

import com.jasonette.template.ExpressionEvaluator
import org.junit.Assert.*
import org.junit.Test

class ExpressionEvaluatorTest {
    private fun eval(expr: String, context: Map<String, Any?> = emptyMap()) =
        ExpressionEvaluator.evaluate(expr, context)

    // Literals
    @Test fun testNumberLiteral() = assertEquals(42, eval("42"))
    @Test fun testFloatLiteral() = assertEquals(3.14, eval("3.14") as Double, 0.001)
    @Test fun testStringLiteral() = assertEquals("hello", eval("'hello'"))
    @Test fun testDoubleQuoteString() = assertEquals("world", eval("\"world\""))
    @Test fun testBoolTrue() = assertEquals(true, eval("true"))
    @Test fun testBoolFalse() = assertEquals(false, eval("false"))
    @Test fun testNull() = assertNull(eval("null"))
    @Test fun testUndefined() = assertNull(eval("undefined"))

    // Arithmetic
    @Test fun testAddition() = assertEquals(5, eval("2 + 3"))
    @Test fun testSubtraction() = assertEquals(6, eval("10 - 4"))
    @Test fun testMultiplication() = assertEquals(21, eval("3 * 7"))
    @Test fun testDivision() = assertEquals(5, eval("15 / 3"))
    @Test fun testModulo() = assertEquals(1, eval("10 % 3"))

    // Comparison
    @Test fun testLessThan() = assertEquals(true, eval("3 < 5"))
    @Test fun testGreaterThan() = assertEquals(true, eval("5 > 3"))
    @Test fun testEquality() = assertEquals(true, eval("5 == 5"))
    @Test fun testInequality() = assertEquals(true, eval("5 != 3"))

    // Logical
    @Test fun testLogicalAnd() = assertEquals(true, eval("true && true"))
    @Test fun testLogicalOr() = assertEquals(true, eval("false || true"))
    @Test fun testLogicalNot() = assertEquals(true, eval("!false"))

    // Ternary
    @Test fun testTernary() = assertEquals("yes", eval("true ? 'yes' : 'no'"))
    @Test fun testTernaryFalse() = assertEquals("no", eval("false ? 'yes' : 'no'"))

    // Member access
    @Test fun testMemberAccess() {
        assertEquals("Bob", eval("user.name", mapOf("user" to mapOf("name" to "Bob"))))
    }

    @Test fun testNestedMember() {
        val ctx = mapOf("a" to mapOf("b" to mapOf("c" to 99)))
        assertEquals(99, eval("a.b.c", ctx))
    }

    // Array
    @Test fun testArrayLiteral() {
        val result = eval("[1, 2, 3]") as? List<*>
        assertNotNull(result)
        assertEquals(3, result?.size)
    }

    // In operator
    @Test fun testInOperator() {
        assertEquals(true, eval("'name' in obj", mapOf("obj" to mapOf("name" to "test"))))
    }

    // Typeof
    @Test fun testTypeofString() = assertEquals("string", eval("typeof 'hello'"))
    @Test fun testTypeofNumber() = assertEquals("number", eval("typeof 42"))
    @Test fun testTypeofBoolean() = assertEquals("boolean", eval("typeof true"))

    // Safe functions
    @Test fun testParseInt() = assertEquals(42, eval("parseInt('42')"))
    @Test fun testMathFloor() = assertEquals(3, eval("Math.floor(3.7)"))

    // Security
    @Test fun testBlockedProperty() = assertNull(eval("obj.__proto__", mapOf("obj" to mapOf("key" to "val"))))
    @Test fun testBlockedConstructor() = assertNull(eval("obj.constructor", mapOf("obj" to mapOf("key" to "val"))))

    // Context variables in arithmetic
    @Test fun testContextArithmetic() {
        assertEquals(30, eval("a + b", mapOf("a" to 10, "b" to 20)))
    }

    @Test fun testStringConcat() {
        assertEquals("John Doe", eval("first + ' ' + last", mapOf("first" to "John", "last" to "Doe")))
    }
}
