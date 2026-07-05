package com.jasonette

import com.jasonette.template.TemplateEngine
import org.junit.Assert.*
import org.junit.Test

class TemplateEngineTest {
    // String interpolation
    @Test fun testSimpleInterpolation() {
        assertEquals("Hello World", TemplateEngine.render("Hello {{name}}", mapOf("name" to "World")))
    }

    @Test fun testSingleExpression() {
        assertEquals(42, TemplateEngine.render("{{count}}", mapOf("count" to 42)))
    }

    @Test fun testNestedAccess() {
        assertEquals("Alice", TemplateEngine.render("{{user.name}}", mapOf("user" to mapOf("name" to "Alice"))))
    }

    @Test fun testArithmeticExpression() {
        assertEquals(30, TemplateEngine.render("{{a + b}}", mapOf("a" to 10, "b" to 20)))
    }

    @Test fun testTernary() {
        assertEquals("Yes", TemplateEngine.render("{{active ? 'Yes' : 'No'}}", mapOf("active" to true)))
    }

    // #each
    @Test fun testEachDirective() {
        val template = listOf(
            mapOf("{{#each items}}" to mapOf("type" to "label", "text" to "{{${'$'}jason}}"))
        )
        val result = TemplateEngine.render(template, mapOf("items" to listOf("a", "b", "c"))) as? List<*>
        assertNotNull(result)
        assertEquals(3, result?.size)
        assertEquals("a", (result?.get(0) as? Map<*, *>)?.get("text"))
    }

    @Test fun testEachWithIndex() {
        val template = listOf(
            mapOf("{{#each items}}" to mapOf("text" to "{{${'$'}index}}"))
        )
        val result = TemplateEngine.render(template, mapOf("items" to listOf("x", "y"))) as? List<*>
        assertEquals(0, (result?.get(0) as? Map<*, *>)?.get("text"))
        assertEquals(1, (result?.get(1) as? Map<*, *>)?.get("text"))
    }

    // #if
    @Test fun testIfTrue() {
        val template = listOf(
            mapOf("{{#if show}}" to mapOf("type" to "label", "text" to "Visible"))
        )
        val result = TemplateEngine.render(template, mapOf("show" to true)) as? List<*>
        assertEquals(1, result?.size)
    }

    @Test fun testIfFalse() {
        val template = listOf(
            mapOf("{{#if show}}" to mapOf("type" to "label", "text" to "Visible"))
        )
        val result = TemplateEngine.render(template, mapOf("show" to false)) as? List<*>
        assertEquals(0, result?.size)
    }

    @Test fun testSplitIfElseArrayRendersOnlyMatchingBranch() {
        val template = listOf(
            mapOf("{{#if show}}" to mapOf("text" to "Visible")),
            mapOf("{{#else}}" to mapOf("text" to "Hidden"))
        )

        val trueResult = TemplateEngine.render(template, mapOf("show" to true)) as? List<*>
        val falseResult = TemplateEngine.render(template, mapOf("show" to false)) as? List<*>

        assertEquals(listOf(mapOf("text" to "Visible")), trueResult)
        assertEquals(listOf(mapOf("text" to "Hidden")), falseResult)
    }

    @Test fun testSplitIfElseifElseStopsBeforeNextSibling() {
        val template = listOf(
            mapOf("{{#if first}}" to mapOf("text" to "First")),
            mapOf("{{#elseif second}}" to mapOf("text" to "Second")),
            mapOf("{{#else}}" to mapOf("text" to "Fallback")),
            mapOf("text" to "Sibling")
        )

        val result = TemplateEngine.render(template, mapOf("first" to false, "second" to true)) as? List<*>

        assertEquals(listOf(mapOf("text" to "Second"), mapOf("text" to "Sibling")), result)
    }

    @Test fun testNestedSplitIfElseInsideBranchStaysScopedToBranch() {
        val template = listOf(
            mapOf(
                "{{#if outer}}" to listOf(
                    mapOf("{{#if inner}}" to mapOf("text" to "Inner")),
                    mapOf("{{#else}}" to mapOf("text" to "Inner fallback"))
                )
            ),
            mapOf("{{#else}}" to mapOf("text" to "Outer fallback")),
            mapOf("text" to "Sibling")
        )

        val result = TemplateEngine.render(template, mapOf("outer" to true, "inner" to false)) as? List<*>

        assertEquals(listOf(mapOf("text" to "Inner fallback"), mapOf("text" to "Sibling")), result)
    }

    // Dictionary rendering
    @Test fun testDictionaryRendering() {
        val template = mapOf("type" to "label", "text" to "{{greeting}}")
        val result = TemplateEngine.render(template, mapOf("greeting" to "Hi")) as? Map<*, *>
        assertEquals("label", result?.get("type"))
        assertEquals("Hi", result?.get("text"))
    }

    // Passthrough
    @Test fun testIntPassthrough() {
        assertEquals(42, TemplateEngine.render(42, emptyMap()))
    }

    @Test fun testBoolPassthrough() {
        assertEquals(true, TemplateEngine.render(true, emptyMap()))
    }

    // Comparison
    @Test fun testComparison() {
        assertEquals(true, TemplateEngine.render("{{a > b}}", mapOf("a" to 10, "b" to 5)))
    }

    // String concatenation
    @Test fun testStringConcatenation() {
        assertEquals("John Doe", TemplateEngine.render("{{first + ' ' + last}}", mapOf("first" to "John", "last" to "Doe")))
    }
}
