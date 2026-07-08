package com.jasonette

import com.jasonette.components.componentImageURL
import com.jasonette.components.effectiveComponentType
import com.jasonette.components.htmlComponentLoadKey
import com.jasonette.components.htmlComponentSource
import com.jasonette.components.htmlComponentUrl
import com.jasonette.components.mapPinLabels
import com.jasonette.components.mapRegionLabel
import com.jasonette.core.DocumentLoader
import com.jasonette.core.JasonBody
import com.jasonette.core.JasonComponent
import com.jasonette.core.JasonHead
import com.jasonette.core.JasonHeader
import com.jasonette.core.JasonHref
import com.jasonette.rendering.bodyBackgroundCss
import com.jasonette.rendering.bodyHasCameraBackground
import com.jasonette.rendering.footerTabComponent
import com.jasonette.rendering.topBarTitle
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class AndroidFooterRenderingTest {
    @Test
    fun testHtmlComponentSourceIncludesInlineCssBeforeText() {
        val component = JasonComponent(
            type = "html",
            css = "p{color:red;}",
            text = "<p>Hello</p>"
        )

        assertEquals("<style>p{color:red;}</style><p>Hello</p>", htmlComponentSource(component))
    }

    @Test
    fun testHtmlComponentHelpersAllowOnlyHttpUrlsAndAvoidDuplicateLoadKeys() {
        val safe = JasonComponent(type = "html", url = "https://example.com/page.html")
        val unsafe = JasonComponent(type = "html", url = "javascript:alert(1)")

        assertEquals("https://example.com/page.html", htmlComponentUrl(safe))
        assertEquals("url:https://example.com/page.html", htmlComponentLoadKey(safe))
        assertNull(htmlComponentUrl(unsafe))
        assertNull(htmlComponentLoadKey(unsafe))
    }

    @Test
    fun testJasonpediaHtmlFixtureDecodesCssAndText() {
        val document = loadJasonpediaFixture("Jasonpedia/view/component/html/index.json")
        val component = document.jason.body?.sections?.first()?.items?.first()

        assertNotNull(component)
        val source = htmlComponentSource(component!!)
        assertEquals("html", component.type)
        assertEquals("html", effectiveComponentType(component))
        assertTrue(component.css?.contains("img{width: 100%;}") == true)
        assertTrue(source?.contains("<style>img{width: 100%;}") == true)
        assertTrue(source?.contains("Continue reading") == true)
    }

    @Test
    fun testJasonpediaMapFixtureDecodesRegionPinsAndVisibleLabels() {
        val document = loadJasonpediaFixture("Jasonpedia/view/component/map/index.json")
        val mapInHeader = document.jason.body?.sections?.first()?.header?.components?.getOrNull(1)
        val mapWithPins = document.jason.body?.sections?.getOrNull(2)?.items?.first()

        assertNotNull(mapInHeader)
        assertEquals("map", mapInHeader?.type)
        assertEquals("map", effectiveComponentType(mapInHeader!!))
        assertEquals("Region 40.7197614,-73.9909211 (200m x 200m)", mapRegionLabel(mapInHeader))

        assertNotNull(mapWithPins)
        assertEquals("map", mapWithPins?.type)
        assertEquals("Region 40.7197614,-73.9909211 (100m x 100m)", mapRegionLabel(mapWithPins!!))
        assertEquals(
            listOf("This is a pin — It really is. @ 40.7197614,-73.9909211"),
            mapPinLabels(mapWithPins)
        )
    }

    @Test
    fun testMapPinFallbackLabelsWhenTitleMissing() {
        val document = DocumentLoader().decode(
            """
            {
              "${'$'}jason": {
                "body": {
                  "sections": [{"items": [{
                    "type": "map",
                    "pins": [{"coord": "1,2"}]
                  }]}]
                }
              }
            }
            """.trimIndent()
        )
        val component = document.jason.body?.sections?.first()?.items?.first()

        assertEquals(listOf("Pin 1 @ 1,2"), mapPinLabels(component!!))
    }

    @Test
    fun testBodyHeaderTitleOverridesHeadTitleForTopBar() {
        val head = JasonHead(title = "Head title")
        val body = JasonBody(header = JasonHeader(title = "Body header"))

        assertEquals("Body header", topBarTitle(head, body))
    }

    @Test
    fun testTopBarTitleFallsBackToHeadTitle() {
        assertEquals("Head title", topBarTitle(JasonHead(title = "Head title"), JasonBody()))
    }

    @Test
    fun testBodyBackgroundCssPrefersStyleBackgroundThenBackgroundString() {
        assertEquals("#112233", bodyBackgroundCss(JasonBody(background = JsonPrimitive("#112233"))))
        assertEquals(
            "#445566",
            bodyBackgroundCss(
                JasonBody(
                    background = JsonPrimitive("#112233"),
                    style = JsonObject(mapOf("background" to JsonPrimitive("#445566")))
                )
            )
        )
    }

    @Test
    fun testBodyStyleBackgroundObjectDecodesWithoutBlockingDocument() {
        val document = DocumentLoader().decode(
            """
            {
              "${'$'}jason": {
                "body": {
                  "style": {
                    "background": {"type": "html", "text": "<h1>BG</h1>"}
                  },
                  "sections": [{"items": [{"type": "label", "text": "Loaded"}]}]
                }
              }
            }
            """.trimIndent()
        )

        assertNull(bodyBackgroundCss(document.jason.body))
        assertEquals("Loaded", document.jason.body?.sections?.first()?.items?.first()?.text)
    }

    @Test
    fun testBodyCameraBackgroundHelperRecognizesBackgroundAndStyleShapes() {
        val objectCamera = JsonObject(mapOf("type" to JsonPrimitive("camera")))

        assertTrue(bodyHasCameraBackground(JasonBody(background = JsonPrimitive("camera"))))
        assertTrue(bodyHasCameraBackground(JasonBody(background = objectCamera)))
        assertTrue(bodyHasCameraBackground(JasonBody(style = JsonObject(mapOf("background" to JsonPrimitive("camera"))))))
        assertTrue(bodyHasCameraBackground(JasonBody(style = JsonObject(mapOf("background" to objectCamera)))))
        assertFalse(bodyHasCameraBackground(JasonBody(background = JsonPrimitive("#112233"))))
    }

    @Test
    fun testBodyBackgroundObjectDecodesWithoutCssColor() {
        val document = DocumentLoader().decode(
            """
            {
              "${'$'}jason": {
                "body": {
                  "background": {"type": "html", "text": "<h1>BG</h1>"}
                }
              }
            }
            """.trimIndent()
        )

        assertNull(bodyBackgroundCss(document.jason.body))
    }

    @Test
    fun testFooterTabShapeRendersImageButNavigatesToUrl() {
        val tab = JasonComponent(
            image = "https://example.com/icon.png",
            text = "Info",
            url = "https://example.com/page.json"
        )

        val navigable = footerTabComponent(tab)

        assertEquals("image", effectiveComponentType(navigable))
        assertEquals("https://example.com/icon.png", componentImageURL(navigable))
        assertEquals("https://example.com/page.json", navigable.href?.url)
    }

    @Test
    fun testFooterTabDoesNotOverwriteAuthoredHref() {
        val tab = JasonComponent(
            text = "Info",
            url = "https://example.com/image-or-legacy-url.png",
            href = JasonHref(url = "https://example.com/authored.json")
        )

        val navigable = footerTabComponent(tab)

        assertEquals("https://example.com/authored.json", navigable.href?.url)
    }

    @Test
    fun testTextOnlyFooterTabUsesUrlForNavigationNotImageRendering() {
        val tab = JasonComponent(text = "Home", url = "https://example.com/home.json")

        val navigable = footerTabComponent(tab)

        assertEquals("label", effectiveComponentType(navigable))
        assertNull(componentImageURL(navigable))
        assertEquals("https://example.com/home.json", navigable.href?.url)
    }

    @Test
    fun testJasonpediaFooterTabsDecodeToNavigableImageTabs() {
        val document = loadJasonpediaFixture("Jasonpedia/view/footer/tabs.json")
        val firstTab = document.jason.body?.footer?.tabs?.items?.first()
        assertNotNull("Expected first footer tab", firstTab)

        val navigable = footerTabComponent(firstTab!!)

        assertEquals("image", effectiveComponentType(navigable))
        assertEquals("https://s3-us-west-2.amazonaws.com/www.jasonclient.org/topsecret%402x.png", componentImageURL(navigable))
        assertEquals(
            "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/view/footer/tabs.json",
            navigable.href?.url
        )
    }

    @Test
    fun testJasonpediaFooterInputControlsInferVisibleComponentTypes() {
        val document = loadJasonpediaFixture("Jasonpedia/view/footer/input.json")
        val input = document.jason.body?.footer?.input
        assertNotNull("Expected footer input", input)
        val footerInput = input!!

        assertEquals("image", effectiveComponentType(footerInput.left!!))
        assertEquals("https://s3.amazonaws.com/www.textcast.co/icons/cam%402x.png", componentImageURL(footerInput.left!!))
        assertEquals("label", effectiveComponentType(footerInput.right!!))
        assertEquals("Send", footerInput.right?.text)
        assertEquals("send", footerInput.right?.action?.trigger)
    }

    private fun loadJasonpediaFixture(path: String) = DocumentLoader().decode(
        listOf(
            File("../../../$path"),
            File("../../$path"),
            File("../$path"),
            File(path)
        ).firstOrNull { it.exists() }?.readText()
            ?: throw IllegalStateException("Fixture $path not found. CWD: ${File(".").absolutePath}")
    )
}
