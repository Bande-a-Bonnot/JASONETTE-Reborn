package com.jasonette.core

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.mutableStateMapOf
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

/**
 * Manages Jasonette state: local ($set/$get) and cache (SharedPreferences).
 */
class StateManager(context: Context? = null) {
    val local = mutableStateMapOf<String, Any?>()

    private val prefs: SharedPreferences? = context?.getSharedPreferences(
        "jasonette_cache", Context.MODE_PRIVATE
    )

    private val json = Json { ignoreUnknownKeys = true }

    // MARK: - Local state ($set / $get)

    fun set(values: Map<String, Any?>) {
        values.forEach { (key, value) -> local[key] = value }
    }

    fun get(): Map<String, Any?> = local.toMap()

    // MARK: - Cache ($cache.set / $cache.get / $cache.reset)

    fun cacheSet(values: Map<String, String>) {
        prefs?.edit()?.apply {
            values.forEach { (key, value) -> putString(key, value) }
            apply()
        }
    }

    fun cacheGet(): Map<String, String?> {
        return prefs?.all?.mapValues { it.value?.toString() } ?: emptyMap()
    }

    fun cacheReset() {
        prefs?.edit()?.clear()?.apply()
    }

    fun flush() {
        local.clear()
        cacheReset()
    }
}
