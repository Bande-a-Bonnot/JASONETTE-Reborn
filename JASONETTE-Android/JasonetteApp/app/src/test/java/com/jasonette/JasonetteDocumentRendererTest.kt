package com.jasonette

import com.jasonette.core.DocumentLoader
import com.jasonette.core.JasonDocument
import com.jasonette.core.StateManager
import com.jasonette.rendering.JasonetteDocumentRenderer
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class JasonetteDocumentRendererTest {
    private val loader = DocumentLoader()

    @Test
    fun testRenderContextExposesGetResponseAndJasonWithoutOverwritingData() {
        val stateManager = StateManager(context = null)
        stateManager.set(
            mapOf(
                "message" to "Hello from local",
                "title" to "Local should win top-level title",
                "\$response" to listOf(mapOf("name" to "Ada", "email" to "ada@example.com"))
            )
        )
        val document = loader.decode(
            """
            {
              "${'$'}jason": {
                "head": {
                  "data": {"title": "Head title"},
                  "templates": {
                    "body": {
                      "sections": [{"items": [
                        {"type": "label", "text": "{{${'$'}jason.title}}"},
                        {"type": "label", "text": "{{${'$'}get.message}}"},
                        {"{{#each ${'$'}response}}": {"type": "label", "text": "{{name}} <{{email}}>"}}
                      ]}]
                    }
                  }
                }
              }
            }
            """.trimIndent()
        )

        val rendered = JasonetteDocumentRenderer(stateManager).render(document)
        val items = rendered.body?.sections?.first()?.items

        assertEquals("Head title", items?.get(0)?.text)
        assertEquals("Hello from local", items?.get(1)?.text)
        assertEquals("Ada <ada@example.com>", items?.get(2)?.text)
    }

    @Test
    fun testJasonpediaNetworkFixtureRendersResponseItemsByFieldName() {
        val stateManager = StateManager(context = null)
        stateManager.set(
            mapOf(
                "\$response" to listOf(
                    mapOf(
                        "name" to "Ada Lovelace",
                        "email" to "ada@example.com",
                        "body" to "First programmable response"
                    )
                )
            )
        )
        val document = loadJasonpediaFixture("Jasonpedia/action/network/eliza.json")

        val rendered = JasonetteDocumentRenderer(stateManager).render(document)
        val renderedItem = rendered.body?.sections?.first()?.items?.first()
        val labels = renderedItem?.components ?: emptyList()

        assertEquals("vertical", renderedItem?.type)
        assertEquals("Ada Lovelace", labels.getOrNull(0)?.text)
        assertEquals("ada@example.com", labels.getOrNull(1)?.text)
        assertEquals("First programmable response", labels.getOrNull(2)?.text)
    }

    @Test
    fun testEachItemFieldsShadowParentButReservedValuesAreRestored() {
        val template = listOf(
            mapOf(
                "{{#each items}}" to mapOf(
                    "name" to "{{name}}",
                    "index" to "{{${'$'}index}}",
                    "current" to "{{${'$'}jason.name}}",
                    "root" to "{{${'$'}root.name}}"
                )
            )
        )
        val result = com.jasonette.template.TemplateEngine.render(
            template,
            mapOf(
                "name" to "parent",
                "${'$'}jason" to mapOf("name" to "root"),
                "items" to listOf(
                    mapOf("name" to "child", "${'$'}index" to 99, "${'$'}jason" to "not current")
                )
            )
        ) as List<*>

        @Suppress("UNCHECKED_CAST")
        val item = result.first() as Map<String, Any?>
        assertEquals("child", item["name"])
        assertEquals(0, item["index"])
        assertEquals("child", item["current"])
        assertEquals("root", item["root"])
    }

    private fun loadJasonpediaFixture(path: String): JasonDocument {
        val candidates = listOf(
            File("../../../$path"),
            File("../../$path"),
            File("../$path"),
            File(path)
        )
        val file = candidates.firstOrNull { it.exists() }
            ?: throw IllegalStateException("Fixture $path not found. Tried: $candidates. CWD: ${File(".").absolutePath}")
        return loader.decode(file.readText())
    }
}
