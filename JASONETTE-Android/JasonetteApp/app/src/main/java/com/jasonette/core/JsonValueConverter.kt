package com.jasonette.core

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Shared bridge between kotlinx.serialization JSON values and the plain Kotlin
 * Map/List/primitives consumed by the Android template and rendering pipeline.
 *
 * Number policy is intentionally shape-aware and mirrors the historical Android
 * renderer contract:
 *
 * - JSON strings stay String.
 * - booleans and null map to Boolean/null.
 * - plain integer-shaped numbers parse as Int, then Long, otherwise preserve
 *   exact token text as String to avoid rounding oversized integers.
 * - decimal or exponent-shaped numbers parse as Double when possible, otherwise
 *   preserve token text as String. Arbitrary-precision decimal/exponent values
 *   are explicitly not preserved today; future cross-platform policy work can
 *   switch this converter in one place if exact decimals become required.
 */
object JsonValueConverter {
    fun jsonElementToAny(element: JsonElement?): Any? {
        if (element == null) return null
        return when (element) {
            is JsonPrimitive -> primitiveToAny(element)
            is JsonArray -> element.map { jsonElementToAny(it) }
            is JsonObject -> element.entries.associate { (key, value) ->
                key to jsonElementToAny(value)
            }
        }
    }

    fun anyToJsonElement(value: Any?): JsonElement =
        when (value) {
            null -> JsonNull
            is String -> JsonPrimitive(value)
            is Int -> JsonPrimitive(value)
            is Long -> JsonPrimitive(value)
            is Double -> JsonPrimitive(value)
            is Float -> JsonPrimitive(value)
            is Boolean -> JsonPrimitive(value)
            is List<*> -> JsonArray(value.map { anyToJsonElement(it) })
            is Map<*, *> -> JsonObject(
                value.entries.associate { (key, item) -> key.toString() to anyToJsonElement(item) }
            )
            else -> JsonPrimitive(value.toString())
        }

    private fun primitiveToAny(primitive: JsonPrimitive): Any? {
        val content = primitive.content
        return when {
            primitive.isString -> content
            content == "true" -> true
            content == "false" -> false
            content == "null" -> null
            content.isDecimalOrExponentNumber() -> content.toDoubleOrNull() ?: content
            else -> content.toIntOrNull() ?: content.toLongOrNull() ?: content
        }
    }

    private fun String.isDecimalOrExponentNumber(): Boolean =
        contains('.') || contains('e', ignoreCase = true)
}
