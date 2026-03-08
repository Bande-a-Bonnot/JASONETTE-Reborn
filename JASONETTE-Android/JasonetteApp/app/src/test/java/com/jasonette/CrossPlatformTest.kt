package com.jasonette

import com.jasonette.core.DocumentLoader
import com.jasonette.template.TemplateEngine
import org.junit.Assert.*
import org.junit.Test
import java.io.File

/**
 * Cross-platform consistency tests that read shared JSON fixtures
 * from the monorepo root `test-fixtures/` directory. The same fixtures
 * are consumed by the iOS test suite so that both engines are
 * validated against identical inputs and expected outputs.
 */
class CrossPlatformTest {

    private fun loadFixture(name: String): Map<String, Any?> {
        // Gradle may run from the module dir (app/) or the project dir (JasonetteApp/)
        val candidates = listOf(
            "../../../test-fixtures/$name",             // from app/
            "../../test-fixtures/$name",                // from JasonetteApp/
            "../test-fixtures/$name",                   // from JASONETTE-Android/
            "test-fixtures/$name"                       // from monorepo root
        )
        val file = candidates.map { File(it) }.firstOrNull { it.exists() }
            ?: throw IllegalStateException(
                "Fixture $name not found. Tried: $candidates. CWD: ${File(".").absolutePath}"
            )
        @Suppress("UNCHECKED_CAST")
        return parseJson(file.readText()) as Map<String, Any?>
    }

    /** Simple recursive JSON parser using kotlinx.serialization is overkill here;
     *  use the org.json classes available on the JVM test classpath. */
    private fun parseJson(text: String): Any? {
        // Use kotlinx.serialization to parse, then convert to plain Map/List/primitives
        val element = kotlinx.serialization.json.Json.parseToJsonElement(text)
        return jsonElementToAny(element)
    }

    private fun jsonElementToAny(element: kotlinx.serialization.json.JsonElement): Any? =
        when (element) {
            is kotlinx.serialization.json.JsonPrimitive -> {
                if (element.isString) element.content
                else if (element.content == "true") true
                else if (element.content == "false") false
                else if (element.content == "null") null
                else if (element.content.contains(".")) element.double
                else element.int
            }
            is kotlinx.serialization.json.JsonArray ->
                element.map { jsonElementToAny(it) }
            is kotlinx.serialization.json.JsonObject ->
                element.toMap().mapValues { (_, v) -> jsonElementToAny(v) }
        }

    // -- Template simple interpolation --

    @Test
    fun testSimpleInterpolation() {
        val fixture = loadFixture("template-simple.json")
        val template = fixture["template"]!!
        @Suppress("UNCHECKED_CAST")
        val context = fixture["context"] as Map<String, Any?>
        val expected = fixture["expected"] as String

        val result = TemplateEngine.render(template, context)
        assertEquals(expected, result)
    }

    // -- Template #each --

    @Test
    fun testEachDirective() {
        val fixture = loadFixture("template-each.json")
        val template = fixture["template"]!!
        @Suppress("UNCHECKED_CAST")
        val context = fixture["context"] as Map<String, Any?>
        val expected = fixture["expected"]!!

        val result = TemplateEngine.render(template, context)
        assertEquals(
            kotlinx.serialization.json.Json.encodeToString(
                kotlinx.serialization.json.JsonElement.serializer(),
                anyToJsonElement(expected)
            ),
            kotlinx.serialization.json.Json.encodeToString(
                kotlinx.serialization.json.JsonElement.serializer(),
                anyToJsonElement(result)
            )
        )
    }

    // -- Template #if true --

    @Test
    fun testIfTrue() {
        val fixture = loadFixture("template-if.json")
        val template = fixture["template"]!!
        @Suppress("UNCHECKED_CAST")
        val contextTrue = fixture["context_true"] as Map<String, Any?>
        val expectedTrue = fixture["expected_true"]!!

        val result = TemplateEngine.render(template, contextTrue)
        assertEquals(
            kotlinx.serialization.json.Json.encodeToString(
                kotlinx.serialization.json.JsonElement.serializer(),
                anyToJsonElement(expectedTrue)
            ),
            kotlinx.serialization.json.Json.encodeToString(
                kotlinx.serialization.json.JsonElement.serializer(),
                anyToJsonElement(result)
            )
        )
    }

    // -- Template #if false --

    @Test
    fun testIfFalse() {
        val fixture = loadFixture("template-if.json")
        val template = fixture["template"]!!
        @Suppress("UNCHECKED_CAST")
        val contextFalse = fixture["context_false"] as Map<String, Any?>

        val result = TemplateEngine.render(template, contextFalse)
        // When condition is false, the engine returns an empty list
        assertTrue(
            "Expected empty list for #if false, got: $result",
            result is List<*> && (result as List<*>).isEmpty()
        )
    }

    // -- Expression evaluation --

    @Test
    fun testExpressions() {
        val fixture = loadFixture("template-expressions.json")
        @Suppress("UNCHECKED_CAST")
        val expressions = fixture["expressions"] as List<Map<String, Any?>>

        for (expr in expressions) {
            val template = expr["expression"] as String
            @Suppress("UNCHECKED_CAST")
            val context = expr["context"] as Map<String, Any?>
            val result = TemplateEngine.render(template, context)

            when {
                expr.containsKey("expected_int") -> {
                    val expected = expr["expected_int"] as Int
                    assertEquals("Failed for $template", expected, result)
                }
                expr.containsKey("expected_double") -> {
                    val expected = expr["expected_double"] as Double
                    assertEquals("Failed for $template", expected, (result as Number).toDouble(), 0.001)
                }
                expr.containsKey("expected_string") -> {
                    val expected = expr["expected_string"] as String
                    assertEquals("Failed for $template", expected, result)
                }
                else -> fail("Expression entry missing expected_int/expected_double/expected_string")
            }
        }
    }

    // -- Document decoding --

    @Test
    fun testDocumentDecoding() {
        val fixture = loadFixture("document-full.json")
        val jsonStr = kotlinx.serialization.json.Json.encodeToString(
            kotlinx.serialization.json.JsonElement.serializer(),
            anyToJsonElement(fixture)
        )
        val doc = DocumentLoader().decode(jsonStr)

        assertEquals("Test", doc.jason.head?.title)
        assertEquals(1, doc.jason.body?.sections?.size)

        val items = doc.jason.body?.sections?.first()?.items
        assertEquals(7, items?.size)
        assertEquals("label", items?.get(0)?.type)
        assertEquals("image", items?.get(1)?.type)
        assertEquals("button", items?.get(2)?.type)
        assertEquals("textfield", items?.get(3)?.type)
        assertEquals("email", items?.get(3)?.keyboard)
        assertEquals("slider", items?.get(4)?.type)
        assertEquals("switch", items?.get(5)?.type)
        assertEquals("space", items?.get(6)?.type)
    }

    // -- Helpers --

    private fun anyToJsonElement(value: Any?): kotlinx.serialization.json.JsonElement =
        when (value) {
            null -> kotlinx.serialization.json.JsonNull
            is Boolean -> kotlinx.serialization.json.JsonPrimitive(value)
            is Int -> kotlinx.serialization.json.JsonPrimitive(value)
            is Long -> kotlinx.serialization.json.JsonPrimitive(value)
            is Double -> kotlinx.serialization.json.JsonPrimitive(value)
            is Float -> kotlinx.serialization.json.JsonPrimitive(value)
            is String -> kotlinx.serialization.json.JsonPrimitive(value)
            is List<*> -> kotlinx.serialization.json.JsonArray(value.map { anyToJsonElement(it) })
            is Map<*, *> -> kotlinx.serialization.json.JsonObject(
                value.entries.associate { (k, v) -> k.toString() to anyToJsonElement(v) }
            )
            else -> kotlinx.serialization.json.JsonPrimitive(value.toString())
        }
}
