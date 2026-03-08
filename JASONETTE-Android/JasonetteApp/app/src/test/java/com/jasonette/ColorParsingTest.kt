package com.jasonette

import androidx.compose.ui.graphics.Color
import com.jasonette.components.parseCssColor
import com.jasonette.components.parseHexColor
import com.jasonette.components.parseRgbColor
import org.junit.Assert.*
import org.junit.Test

class ColorParsingTest {

    private fun assertColorEquals(expected: Color, actual: Color?, tolerance: Float = 0.01f) {
        assertNotNull("Color should not be null", actual)
        actual!!
        assertEquals("red", expected.red, actual.red, tolerance)
        assertEquals("green", expected.green, actual.green, tolerance)
        assertEquals("blue", expected.blue, actual.blue, tolerance)
        assertEquals("alpha", expected.alpha, actual.alpha, tolerance)
    }

    // --- parseHexColor tests ---
    // Note: parseHexColor uses android.graphics.Color.parseColor internally,
    // which is unavailable in pure JUnit. These tests verify the null-safety
    // path (invalid inputs) and are skipped for valid hex parsing. Valid hex
    // colors are tested via parseCssColor integration on devices.

    @Test
    fun testInvalidHexReturnsNull() {
        assertNull(parseHexColor("#GGG"))
        assertNull(parseHexColor("#12345"))    // 5 digits
        assertNull(parseHexColor("#1234567890")) // too long
        assertNull(parseHexColor(""))
    }

    // --- parseRgbColor tests (pure Kotlin, no Android dependency) ---

    @Test
    fun testRgbParsesCorrectly() {
        val result = parseRgbColor("rgb(255,0,128)")
        assertColorEquals(Color(255 / 255f, 0 / 255f, 128 / 255f, 1f), result)
    }

    @Test
    fun testRgbaParsesCorrectly() {
        val result = parseRgbColor("rgba(100,200,50,0.5)")
        assertColorEquals(Color(100 / 255f, 200 / 255f, 50 / 255f, 0.5f), result)
    }

    @Test
    fun testOutOfRangeRgbRejected() {
        assertNull(parseRgbColor("rgb(256,0,0)"))
        assertNull(parseRgbColor("rgb(-1,0,0)"))
        assertNull(parseRgbColor("rgb(0,0,300)"))
    }

    @Test
    fun testNonNumericAlphaRejected() {
        assertNull(parseRgbColor("rgba(100,200,50,abc)"))
    }

    @Test
    fun testWhitespaceTrimmed() {
        val result = parseRgbColor("rgb( 10 , 20 , 30 )")
        assertColorEquals(Color(10 / 255f, 20 / 255f, 30 / 255f, 1f), result)
    }

    @Test
    fun testRgbaFullOpacity() {
        val result = parseRgbColor("rgba(0,0,0,1.0)")
        assertColorEquals(Color(0f, 0f, 0f, 1f), result)
    }

    @Test
    fun testRgbaZeroOpacity() {
        val result = parseRgbColor("rgba(255,255,255,0.0)")
        assertColorEquals(Color(1f, 1f, 1f, 0f), result)
    }

    @Test
    fun testRgbaAlphaClamped() {
        // Alpha > 1.0 should be clamped to 1.0
        val result = parseRgbColor("rgba(128,128,128,2.0)")
        assertColorEquals(Color(128 / 255f, 128 / 255f, 128 / 255f, 1f), result)
    }

    // --- parseCssColor routing tests ---

    @Test
    fun testCssColorRoutesToRgb() {
        val result = parseCssColor("rgb(0,128,255)")
        assertColorEquals(Color(0 / 255f, 128 / 255f, 255 / 255f, 1f), result)
    }

    @Test
    fun testCssColorRoutesToRgba() {
        val result = parseCssColor("rgba(0,0,0,0.5)")
        assertColorEquals(Color(0f, 0f, 0f, 0.5f), result)
    }

    @Test
    fun testCssColorRejectsUnknownFormat() {
        assertNull(parseCssColor("hsl(120,100%,50%)"))
        assertNull(parseCssColor("red"))
        assertNull(parseCssColor(""))
    }

    @Test
    fun testCaseInsensitive() {
        // parseCssColor lowercases input, then routes to parseRgbColor
        val result = parseCssColor("RGB(10,20,30)")
        assertColorEquals(Color(10 / 255f, 20 / 255f, 30 / 255f, 1f), result)
    }

    @Test
    fun testCssWhitespaceTrimmed() {
        val result = parseCssColor("  rgb(0,0,0)  ")
        assertColorEquals(Color(0f, 0f, 0f, 1f), result)
    }
}
