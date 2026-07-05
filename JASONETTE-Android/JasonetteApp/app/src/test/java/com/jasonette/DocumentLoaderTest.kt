package com.jasonette

import com.jasonette.core.DocumentLoader
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.*
import org.junit.Test
import java.io.File

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

    @Test fun testDecodeWithFooterInputAndTriggerAction() {
        val json = """{"${'$'}jason":{"body":{"footer":{"input":{"name":"message","placeholder":"Say something...","left":{"image":"https://example.com/cam.png"},"right":{"text":"Send","action":{"trigger":"send"}}}}}}}"""
        val doc = loader.decode(json)
        val input = doc.jason.body?.footer?.input
        assertEquals("message", input?.name)
        assertEquals("Say something...", input?.placeholder)
        assertEquals("https://example.com/cam.png", input?.left?.image)
        assertEquals("Send", input?.right?.text)
        assertEquals("send", input?.right?.action?.trigger)
    }

    @Test fun testLoadResolvesLegacyWebcontainerTemplateAndDocumentReferences() = runTest {
        val entryUrl = "https://example.com/webcontainer/pdf.json"
        val templateUrl = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/template.json"
        val testLoader = fakeLoader(
            entryUrl to fixture("Jasonpedia/webcontainer/pdf.json"),
            templateUrl to fixture("Jasonpedia/webcontainer/template.json")
        )

        val doc = testLoader.load(entryUrl)
        val bodyTemplate = doc.jason.head?.templates?.body?.jsonObject
        val header = bodyTemplate?.get("header")?.jsonObject
        val style = bodyTemplate?.get("style")?.jsonObject
        val background = style?.get("background")?.jsonObject

        assertEquals("PDF.json", header?.get("title")?.jsonPrimitive?.content)
        assertEquals("#474747", header?.get("style")?.jsonObject?.get("background")?.jsonPrimitive?.content)
        assertTrue(background?.get("text")?.jsonPrimitive?.content?.contains("mozilla.github.io/pdf.js") == true)
        assertEquals("\$default", background?.get("action")?.jsonObject?.get("type")?.jsonPrimitive?.content)
    }

    @Test fun testLoadResolvesLegacyFeedSelectorIncludes() = runTest {
        val entryUrl = "https://example.com/webcontainer/feed/index.json"
        val dbUrl = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/db.json"
        val itemUrl = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/item.json"
        val specialUrl = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/special_item.json"
        val animatedUrl = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/animated_item.json"
        val testLoader = fakeLoader(
            entryUrl to fixture("Jasonpedia/webcontainer/feed/index.json"),
            dbUrl to fixture("Jasonpedia/webcontainer/feed/db.json"),
            itemUrl to fixture("Jasonpedia/webcontainer/feed/item.json"),
            specialUrl to fixture("Jasonpedia/webcontainer/feed/special_item.json"),
            animatedUrl to fixture("Jasonpedia/webcontainer/feed/animated_item.json")
        )

        val doc = testLoader.load(entryUrl)
        val data = doc.jason.head?.data
        val items = data?.get("items")?.jsonArray
        val bodyTemplate = doc.jason.head?.templates?.body?.jsonObject
        val sections = bodyTemplate?.get("sections")?.jsonArray
        val repeatedTemplate = sections?.get(0)?.jsonObject?.get("items")?.jsonObject?.values?.first()?.jsonObject
        val specialItems = sections?.get(1)?.jsonObject?.get("items")?.jsonArray
        val specialItem = specialItems?.get(0)?.jsonObject
        val animatedItem = specialItems?.get(1)?.jsonObject

        assertEquals("ethan", items?.get(0)?.jsonObject?.get("username")?.jsonPrimitive?.content)
        assertEquals("horizontal", repeatedTemplate?.get("type")?.jsonPrimitive?.content)
        assertEquals("vertical", specialItem?.get("type")?.jsonPrimitive?.content)
        assertEquals("vertical", animatedItem?.get("type")?.jsonPrimitive?.content)
    }

    @Test fun testLoadResolvesSelectedIncludeDocumentReferencesAgainstFetchedRoot() = runTest {
        val entryUrl = "https://example.com/entry.json"
        val partsUrl = "https://example.com/parts.json"
        val testLoader = fakeLoader(
            entryUrl to """
                {
                  "${'$'}jason": {
                    "head": {
                      "data": {
                        "item": {"+": "item@$partsUrl"}
                      }
                    }
                  }
                }
            """.trimIndent(),
            partsUrl to """
                {
                  "title": "Fetched title",
                  "item": {"text": {"+": "${'$'}document.title"}}
                }
            """.trimIndent()
        )

        val doc = testLoader.load(entryUrl)
        val item = doc.jason.head?.data?.get("item")?.jsonObject

        assertEquals("Fetched title", item?.get("text")?.jsonPrimitive?.content)
    }

    @Test fun testLoadDoesNotTreatAtSignInsideUrlAsSelectorInclude() = runTest {
        val entryUrl = "https://example.com/entry.json"
        val includeUrl = "https://example.com/parts.json?email=a@b.com"
        val requested = mutableListOf<String>()
        val testLoader = DocumentLoader { url ->
            requested.add(url)
            val body = if (url == entryUrl) {
                """
                {
                  "${'$'}jason": {
                    "head": {
                      "data": {
                        "part": {"+": "$includeUrl"}
                      }
                    }
                  }
                }
                """.trimIndent()
            } else {
                """{"text":"whole document"}"""
            }
            DocumentLoader.LoadedJson(body, url)
        }

        val doc = testLoader.load(entryUrl)
        val part = doc.jason.head?.data?.get("part")?.jsonObject

        assertEquals("whole document", part?.get("text")?.jsonPrimitive?.content)
        assertEquals(listOf(entryUrl, includeUrl), requested)
    }

    @Test fun testLoadAllowsDuplicateSameUrlSelectorIncludes() = runTest {
        val entryUrl = "https://example.com/entry.json"
        val partsUrl = "https://example.com/parts.json"
        val testLoader = fakeLoader(
            entryUrl to """
                {
                  "${'$'}jason": {
                    "head": {
                      "data": {
                        "first": {"+": "first@$partsUrl"},
                        "second": {"+": "second@$partsUrl"}
                      }
                    }
                  }
                }
            """.trimIndent(),
            partsUrl to """{"first":{"text":"one"},"second":{"text":"two"}}"""
        )

        val doc = testLoader.load(entryUrl)
        val data = doc.jason.head?.data

        assertEquals("one", data?.get("first")?.jsonObject?.get("text")?.jsonPrimitive?.content)
        assertEquals("two", data?.get("second")?.jsonObject?.get("text")?.jsonPrimitive?.content)
    }

    @Test fun testLoadGuardsLocalDocumentIncludeCycles() = runTest {
        val entryUrl = "https://example.com/cycle.json"
        val testLoader = fakeLoader(
            entryUrl to """
                {
                  "${'$'}jason": {
                    "head": {
                      "data": {
                        "self": {"+": "${'$'}document.${'$'}jason.head.data.self"}
                      }
                    }
                  }
                }
            """.trimIndent()
        )

        val doc = testLoader.load(entryUrl)

        assertSame(JsonNull, doc.jason.head?.data?.get("self"))
    }

    @Test fun testLoadRejectsUnsafeTopLevelDocumentUrlWithoutFetching() = runTest {
        var fetched = false
        val testLoader = DocumentLoader { url ->
            fetched = true
            DocumentLoader.LoadedJson("{}", url)
        }

        try {
            testLoader.load("file:///tmp/document.json")
            fail("Expected unsafe document URL to be rejected")
        } catch (e: DocumentLoader.DocumentException) {
            assertEquals("Blocked URL scheme", e.message)
        }

        assertFalse(fetched)
    }

    @Test fun testLoadBlocksUnsafeLegacyIncludeSchemes() = runTest {
        val entryUrl = "https://example.com/unsafe.json"
        val requested = mutableListOf<String>()
        val testLoader = DocumentLoader { url ->
            requested.add(url)
            DocumentLoader.LoadedJson(
                """
                {
                  "${'$'}jason": {
                    "head": {
                      "data": {"unsafe": {"+": "file:///tmp/secret.json"}},
                      "title": "Safe"
                    }
                  }
                }
                """.trimIndent(),
                url
            )
        }

        val doc = testLoader.load(entryUrl)

        assertEquals("Safe", doc.jason.head?.title)
        assertEquals(listOf(entryUrl), requested)
    }

    private fun fakeLoader(vararg responses: Pair<String, String>): DocumentLoader {
        val responseMap = responses.toMap()
        return DocumentLoader { url ->
            DocumentLoader.LoadedJson(
                body = responseMap[url] ?: error("No fake response for $url"),
                url = url
            )
        }
    }

    private fun fixture(path: String): String {
        val candidates = listOf(
            File("../../../$path"),
            File("../../$path"),
            File("../$path"),
            File(path)
        )
        val file = candidates.firstOrNull { it.exists() }
            ?: throw IllegalStateException("Fixture $path not found. Tried: $candidates. CWD: ${File(".").absolutePath}")
        return file.readText()
    }
}
