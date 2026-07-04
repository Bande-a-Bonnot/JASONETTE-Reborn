package com.jasonette

import com.jasonette.components.componentImageURL
import com.jasonette.components.effectiveComponentType
import com.jasonette.core.DocumentLoader
import com.jasonette.core.JasonComponent
import com.jasonette.core.JasonHref
import com.jasonette.rendering.footerTabComponent
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class AndroidFooterRenderingTest {
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
