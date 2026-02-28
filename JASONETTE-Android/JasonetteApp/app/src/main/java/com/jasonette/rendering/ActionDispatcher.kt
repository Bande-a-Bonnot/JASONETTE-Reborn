package com.jasonette.rendering

import com.jasonette.core.*
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL

/**
 * Executes Jasonette actions with success/error chaining.
 */
class ActionDispatcher(private val stateManager: StateManager) {

    suspend fun execute(action: JasonAction) {
        try {
            dispatch(action)
            action.success?.let { execute(it) }
        } catch (_: Exception) {
            action.error?.let { execute(it) }
        }
    }

    private suspend fun dispatch(action: JasonAction) {
        val type = action.type ?: return
        val options = action.options

        when (type) {
            "\$set" -> {
                val values = options?.entries?.associate { (k, v) ->
                    k to v.jsonPrimitive.content
                } ?: emptyMap()
                stateManager.set(values)
            }

            "\$get" -> {} // state available via stateManager.local

            "\$cache.set" -> {
                val values = options?.entries?.associate { (k, v) ->
                    k to v.jsonPrimitive.content
                } ?: emptyMap()
                stateManager.cacheSet(values)
            }

            "\$cache.get" -> {}
            "\$cache.reset" -> stateManager.cacheReset()

            "\$render" -> {} // handled by ViewModel re-render
            "\$reload" -> {} // handled by ViewModel

            "\$network.request" -> {
                val urlStr = options?.get("url")?.jsonPrimitive?.content
                    ?: throw ActionException("Missing URL")
                networkRequest(urlStr, options)
            }

            else -> println("[Jasonette] Unknown action: $type")
        }
    }

    private suspend fun networkRequest(urlStr: String, options: kotlinx.serialization.json.JsonObject?) {
        val url = URL(urlStr)
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.requestMethod = options?.get("method")?.jsonPrimitive?.content?.uppercase() ?: "GET"
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000

            val code = conn.responseCode
            if (code !in 200..299) throw ActionException("HTTP error: $code")

            val body = conn.inputStream.bufferedReader().readText()
            // Store response in local state
            try {
                val json = kotlinx.serialization.json.Json.parseToJsonElement(body)
                if (json is kotlinx.serialization.json.JsonObject) {
                    json.entries.forEach { (key, value) ->
                        stateManager.set(mapOf(key to value.jsonPrimitive.content))
                    }
                }
            } catch (_: Exception) {
                // Not JSON, ignore
            }
        } finally {
            conn.disconnect()
        }
    }

    class ActionException(message: String) : Exception(message)
}
