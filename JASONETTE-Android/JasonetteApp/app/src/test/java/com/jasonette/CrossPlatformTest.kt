package com.jasonette

import com.jasonette.core.DocumentLoader
import com.jasonette.template.TemplateEngine
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
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

    /** Simple recursive JSON parser for shared fixture data. */
    private fun parseJson(text: String): Any? {
        // Use kotlinx.serialization to parse, then convert to plain Map/List/primitives
        val element = Json.parseToJsonElement(text)
        return jsonElementToAny(element)
    }

    private fun jsonElementToAny(element: JsonElement): Any? =
        when (element) {
            is JsonPrimitive -> {
                val content = element.content
                if (element.isString) content
                else if (content == "true") true
                else if (content == "false") false
                else if (content == "null") null
                else if (content.contains('.') || content.contains('e', ignoreCase = true)) content.toDoubleOrNull() ?: content
                else content.toIntOrNull() ?: content.toLongOrNull() ?: content
            }
            is JsonArray ->
                element.map { jsonElementToAny(it) }
            is JsonObject ->
                element.toMap().mapValues { (_, v) -> jsonElementToAny(v) }
        }

    @Test
    fun testOversizedIntegerFixtureValuePreservesPrecision() {
        assertEquals("9223372036854775808", parseJson("9223372036854775808"))
        assertEquals("-9223372036854775809", parseJson("-9223372036854775809"))
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
            Json.encodeToString(
                JsonElement.serializer(),
                anyToJsonElement(expected)
            ),
            Json.encodeToString(
                JsonElement.serializer(),
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
            Json.encodeToString(
                JsonElement.serializer(),
                anyToJsonElement(expectedTrue)
            ),
            Json.encodeToString(
                JsonElement.serializer(),
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
        val jsonStr = Json.encodeToString(
            JsonElement.serializer(),
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

    private fun anyToJsonElement(value: Any?): JsonElement =
        when (value) {
            null -> JsonNull
            is Boolean -> JsonPrimitive(value)
            is Int -> JsonPrimitive(value)
            is Long -> JsonPrimitive(value)
            is Double -> JsonPrimitive(value)
            is Float -> JsonPrimitive(value)
            is String -> JsonPrimitive(value)
            is List<*> -> JsonArray(value.map { anyToJsonElement(it) })
            is Map<*, *> -> JsonObject(
                value.entries.associate { (k, v) -> k.toString() to anyToJsonElement(v) }
            )
            else -> JsonPrimitive(value.toString())
        }
}
