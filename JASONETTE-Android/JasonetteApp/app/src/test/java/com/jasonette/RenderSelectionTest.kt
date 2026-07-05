package com.jasonette

import com.jasonette.rendering.RenderSelection
import org.junit.Assert.*
import org.junit.Test

class RenderSelectionTest {
    @Test
    fun testRenderWithoutDataPreservesCurrentPayload() {
        val selection = RenderSelection()
        val payload = mapOf("title" to "First")

        selection.apply(templateName = "detail", renderData = payload)
        selection.apply(templateName = "summary", renderData = null)

        assertEquals("summary", selection.templateName)
        assertSame(payload, selection.renderData)
        assertTrue(selection.hasRenderData)
    }

    @Test
    fun testExplicitNullPayloadClearsCurrentPayload() {
        val selection = RenderSelection()

        selection.apply(templateName = "detail", renderData = mapOf("title" to "First"))
        selection.apply(templateName = "summary", renderData = null, hasRenderData = true)

        assertEquals("summary", selection.templateName)
        assertNull(selection.renderData)
        assertTrue(selection.hasRenderData)
    }

    @Test
    fun testResetReturnsToBodyAndClearsPayload() {
        val selection = RenderSelection()

        selection.apply(templateName = "detail", renderData = mapOf("title" to "First"))
        selection.reset()

        assertEquals("body", selection.templateName)
        assertNull(selection.renderData)
        assertFalse(selection.hasRenderData)
    }
}
