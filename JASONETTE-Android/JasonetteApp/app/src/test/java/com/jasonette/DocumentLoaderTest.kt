package com.jasonette

import com.jasonette.core.DocumentLoader
import org.junit.Assert.*
import org.junit.Test

class DocumentLoaderTest {
    private val loader = DocumentLoader()

    @Test fun testDecodeMinimalDocument() {
        val json = """{"${'$'}jason":{"head":{"title":"Test"},"body":{"sections":[{"items":[{"type":"label","text":"Hello"}]}]}}}"""
        val doc = loader.decode(json)
        assertEquals("Test", doc.jason.head?.title)
        assertEquals(1, doc.jason.body?.sections?.size)
        assertEquals("label", doc.jason.body?.sections?.first()?.items?.first()?.type)
        assertEquals("Hello", doc.jason.body?.sections?.first()?.items?.first()?.text)
    }

    @Test fun testDecodeWithStyles() {
        val json = """{"${'$'}jason":{"head":{"title":"Styled","styles":{"bold_label":{"color":"#FF0000","size":18}}}}}"""
        val doc = loader.decode(json)
        val styles = doc.jason.head?.styles
        assertNotNull(styles?.get("bold_label"))
        assertEquals("#FF0000", styles?.get("bold_label")?.color)
    }

    @Test fun testDecodeWithActions() {
        val json = """{"${'$'}jason":{"head":{"actions":{"${'$'}load":{"type":"${'$'}network.request","success":{"type":"${'$'}render"}}}}}}"""
        val doc = loader.decode(json)
        val load = doc.jason.head?.actions?.get("\$load")
        assertEquals("\$network.request", load?.type)
        assertEquals("\$render", load?.success?.type)
    }

    @Test fun testDecodeWithHref() {
        val json = """{"${'$'}jason":{"body":{"sections":[{"items":[{"type":"label","text":"Go","href":{"url":"https://example.com","view":"web","transition":"push"}}]}]}}}"""
        val doc = loader.decode(json)
        val href = doc.jason.body?.sections?.first()?.items?.first()?.href
        assertEquals("https://example.com", href?.url)
        assertEquals("web", href?.view)
        assertEquals("push", href?.transition)
    }

    @Test fun testDecodeWithNestedComponents() {
        val json = """{"${'$'}jason":{"body":{"sections":[{"items":[{"type":"horizontal","components":[{"type":"image","url":"https://example.com/pic.jpg"},{"type":"label","text":"Caption"}]}]}]}}}"""
        val doc = loader.decode(json)
        val item = doc.jason.body?.sections?.first()?.items?.first()
        assertEquals("horizontal", item?.type)
        assertEquals(2, item?.components?.size)
    }

    @Test fun testDecodeWithFooterTabs() {
        val json = """{"${'$'}jason":{"body":{"footer":{"tabs":{"items":[{"text":"Home"},{"text":"Settings"}]}}}}}"""
        val doc = loader.decode(json)
        val tabs = doc.jason.body?.footer?.tabs?.items
        assertEquals(2, tabs?.size)
        assertEquals("Home", tabs?.get(0)?.text)
    }
}
