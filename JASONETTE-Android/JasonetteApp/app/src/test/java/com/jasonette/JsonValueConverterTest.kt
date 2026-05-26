package com.jasonette

import com.jasonette.core.JsonValueConverter
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class JsonValueConverterTest {
    @Test
    fun plainIntegersUseIntThenLongThenExactString() {
        assertEquals(42, parse("42"))
        assertEquals(2147483648L, parse("2147483648"))
        assertEquals("9223372036854775808", parse("9223372036854775808"))
        assertEquals("-9223372036854775809", parse("-9223372036854775809"))
    }

    @Test
    fun highPrecisionDecimalsUseDoubleByPolicy() {
        val raw = "0.123456789012345678901234567890"
        val parsed = parse(raw)

        assertTrue(parsed is Double)
        assertEquals(raw.toDouble(), parsed as Double, 0.0)
    }

    @Test
    fun exponentNumbersUseDoubleByPolicy() {
        val parsed = parse("1.234567890123456789e30")

        assertTrue(parsed is Double)
        assertEquals("1.2345678901234568E30", (parsed as Double).toString())
    }

    @Test
    fun anyToJsonElementRoundTripsLongValues() {
        val value = mapOf("id" to 2147483648L)
        val element = JsonValueConverter.anyToJsonElement(value)

        assertEquals(value, JsonValueConverter.jsonElementToAny(element))
    }

    private fun parse(json: String): Any? =
        JsonValueConverter.jsonElementToAny(Json.parseToJsonElement(json))
}
