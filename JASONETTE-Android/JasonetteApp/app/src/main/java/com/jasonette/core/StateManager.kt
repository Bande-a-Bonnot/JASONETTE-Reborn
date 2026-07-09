package com.jasonette.core

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.mutableStateMapOf
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

/**
 * Manages Jasonette state: local ($set/$get) and cache (SharedPreferences).
 */
class StateManager(context: Context? = null) {
    val local = mutableStateMapOf<String, Any?>()

    private val prefs: SharedPreferences? = context?.getSharedPreferences(
        "jasonette_cache", Context.MODE_PRIVATE
    )
    private val globalPrefs: SharedPreferences? = context?.getSharedPreferences(
        "global", Context.MODE_PRIVATE
    )
    private val sessionPrefs: SharedPreferences? = context?.getSharedPreferences(
        "session", Context.MODE_PRIVATE
    )
    private val inMemoryGlobal = mutableMapOf<String, Any?>()
    private val inMemorySession = mutableMapOf<String, Map<String, Any?>>()

    private val json = Json { ignoreUnknownKeys = true }

    init {
        refreshGlobalFromPrefs()
    }

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

    // MARK: - Global state ($global.set / $global.reset)

    fun globalSet(values: Map<String, Any?>): Map<String, Any?> {
        inMemoryGlobal.putAll(values)
        globalPrefs?.edit()?.apply {
            values.forEach { (key, value) -> putString(key, encodeStoredValue(value)) }
            apply()
        }
        return globalGet()
    }

    fun globalReset(items: List<String>): Map<String, Any?> {
        items.forEach { inMemoryGlobal.remove(it) }
        globalPrefs?.edit()?.apply {
            items.forEach { remove(it) }
            apply()
        }
        return globalGet()
    }

    fun globalGet(): Map<String, Any?> {
        refreshGlobalFromPrefs()
        return inMemoryGlobal.toMap()
    }

    // MARK: - Session state ($session.set / $session.reset)

    fun sessionSet(domain: String, values: Map<String, Any?>) {
        val key = domain.lowercase()
        inMemorySession[key] = values
        sessionPrefs?.edit()?.putString(key, encodeStoredValue(values))?.apply()
    }

    fun sessionReset(domain: String) {
        val key = domain.lowercase()
        inMemorySession.remove(key)
        sessionPrefs?.edit()?.remove(key)?.apply()
    }

    fun sessionForDomain(domain: String): Map<String, Any?>? {
        val key = domain.lowercase()
        if (sessionPrefs == null) return inMemorySession[key]
        val stored = sessionPrefs.getString(key, null) ?: run {
            inMemorySession.remove(key)
            return null
        }
        val decoded = decodeStoredValue(stored) as? Map<*, *> ?: return null
        val session = decoded.entries.associate { (k, v) -> k.toString() to v }
        inMemorySession[key] = session
        return session
    }

    fun flush() {
        local.clear()
        cacheReset()
    }

    private fun refreshGlobalFromPrefs() {
        val prefs = globalPrefs ?: return
        inMemoryGlobal.clear()
        prefs.all.forEach { (key, value) ->
            inMemoryGlobal[key] = decodeStoredValue(value?.toString())
        }
    }

    private fun encodeStoredValue(value: Any?): String = json.encodeToString(
        JsonElement.serializer(),
        JsonValueConverter.anyToJsonElement(value)
    )

    private fun decodeStoredValue(value: String?): Any? {
        if (value == null) return null
        return try {
            JsonValueConverter.jsonElementToAny(json.parseToJsonElement(value))
        } catch (_: Exception) {
            value
        }
    }
}
