package com.jasonette

import com.jasonette.core.JasonStyle
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.floatOrNull
import org.junit.Assert.*
import org.junit.Test

class StyleModifierTest {

    @Test
    fun testSingleStyleProperties() {
        val style = JasonStyle(
            font = "Helvetica",
            size = JsonPrimitive(16),
            color = "#FF0000",
            background = "#FFFFFF",
            align = "center"
        )
        assertEquals("Helvetica", style.font)
        assertEquals(16f, style.size?.floatOrNull)
        assertEquals("#FF0000", style.color)
        assertEquals("#FFFFFF", style.background)
        assertEquals("center", style.align)
    }

    @Test
    fun testMergeOverridesLaterWins() {
        val base = JasonStyle(
            color = "#000000",
            font = "Arial",
            size = JsonPrimitive(14)
        )
        val overlay = JasonStyle(
            color = "#FF0000",
            size = JsonPrimitive(20)
        )
        // mergeWith: other overrides this
        val merged = base.mergeWith(overlay)
        assertEquals("#FF0000", merged.color)        // overlay wins
        assertEquals(20f, merged.size?.floatOrNull)   // overlay wins
        assertEquals("Arial", merged.font)            // base preserved
    }

    @Test
    fun testMergePreservesUnsetProperties() {
        val base = JasonStyle(
            color = "#000000",
            background = "#EEEEEE",
            padding = JsonPrimitive(10),
            align = "left"
        )
        val overlay = JasonStyle(
            font = "Menlo"
            // color, background, padding, align all null
        )
        val merged = base.mergeWith(overlay)
        assertEquals("#000000", merged.color)
        assertEquals("#EEEEEE", merged.background)
        assertEquals(10f, merged.padding?.floatOrNull)
        assertEquals("left", merged.align)
        assertEquals("Menlo", merged.font)
    }

    @Test
    fun testMultiClassMergeChain() {
        // Simulates resolving "bold padded colored" by chaining mergeWith
        val bold = JasonStyle(font = "Helvetica-Bold", size = JsonPrimitive(18))
        val padded = JasonStyle(padding = JsonPrimitive(12))
        val colored = JasonStyle(color = "#0000FF", size = JsonPrimitive(24))

        val merged = listOf(bold, padded, colored)
            .reduceOrNull { acc, style -> acc.mergeWith(style) }

        assertNotNull(merged)
        assertEquals("Helvetica-Bold", merged?.font)  // from bold
        assertEquals(12f, merged?.padding?.floatOrNull) // from padded
        assertEquals("#0000FF", merged?.color)          // from colored
        assertEquals(24f, merged?.size?.floatOrNull)    // colored overrides bold
    }

    @Test
    fun testEmptyStyleReturnsDefaults() {
        val style = JasonStyle()
        assertNull(style.font)
        assertNull(style.size)
        assertNull(style.color)
        assertNull(style.background)
        assertNull(style.padding)
        assertNull(style.align)
        assertNull(style.spacing)
        assertNull(style.cornerRadius)
        assertNull(style.borderWidth)
        assertNull(style.borderColor)
    }
}
