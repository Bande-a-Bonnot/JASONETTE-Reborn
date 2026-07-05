package com.jasonette.rendering

import com.jasonette.core.*
import com.jasonette.template.TemplateEngine
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

/**
 * Executes Jasonette actions with success/error chaining.
 */
class ActionDispatcher(
    private val stateManager: StateManager,
    private var baseUrl: String? = null,
    private val networkClient: (suspend (String, kotlinx.serialization.json.JsonObject?) -> String)? = null
) {
    data class UtilityMessage(
        val kind: String,
        val title: String? = null,
        val description: String? = null,
        val text: String? = null
    )

    private var renderHandler: ((String?, Any?, Boolean) -> Unit)? = null
    private var reloadHandler: (() -> Unit)? = null
    private var navigationHandler: ((JasonHref) -> Unit)? = null
    private var backHandler: (() -> Unit)? = null
    private var closeHandler: (() -> Unit)? = null
    private var actionResolver: ((String) -> JasonAction?)? = null
    private var utilityHandler: ((UtilityMessage) -> Unit)? = null

    fun setBaseUrl(url: String?) {
        baseUrl = url
    }

    fun setRenderHandler(handler: ((String?, Any?, Boolean) -> Unit)?) {
        renderHandler = handler
    }

    fun setReloadHandler(handler: (() -> Unit)?) {
        reloadHandler = handler
    }

    fun setNavigationHandler(handler: ((JasonHref) -> Unit)?) {
        navigationHandler = handler
    }

    fun setBackHandler(handler: (() -> Unit)?) {
        backHandler = handler
    }

    fun setCloseHandler(handler: (() -> Unit)?) {
        closeHandler = handler
    }

    fun setActionResolver(handler: ((String) -> JasonAction?)?) {
        actionResolver = handler
    }

    fun setUtilityHandler(handler: ((UtilityMessage) -> Unit)?) {
        utilityHandler = handler
    }

    suspend fun execute(action: JasonAction) {
        try {
            dispatch(action)
            action.success?.let { execute(it) }
        } catch (_: Exception) {
            action.error?.let { execute(it) }
        }
    }

    private suspend fun dispatch(action: JasonAction) {
        if (action.type == null) {
            action.trigger?.let { trigger ->
                actionResolver?.invoke(trigger)?.let { execute(it) }
            }
            return
        }
        val type = action.type ?: return
        val options = templatedOptions(action.options)

        when (type) {
            "\$set" -> {
                val values = options?.entries?.associate { (k, v) ->
                    k to JsonValueConverter.jsonElementToAny(v)
                } ?: emptyMap()
                stateManager.set(values)
            }

            "\$get" -> {} // state available via stateManager.local
            "\$flush" -> stateManager.cacheReset()

            "\$cache.set" -> {
                val values = options?.entries?.associate { (k, v) ->
                    k to jsonElementToString(v)
                } ?: emptyMap()
                stateManager.cacheSet(values)
            }

            "\$cache.get" -> {}
            "\$cache.reset" -> stateManager.cacheReset()

            "\$render" -> renderHandler?.invoke(
                stringOption(options, "template"),
                renderDataOption(options),
                options?.containsKey("data") == true
            )
            "\$reload" -> reloadHandler?.invoke()

            "\$network.request" -> {
                val urlStr = (options?.get("url") as? JsonPrimitive)?.content
                    ?: throw ActionException("Missing URL")
                networkRequest(urlStr, options)
            }

            "\$href" -> {
                val href = hrefFromOptions(options)
                dispatchHref(href)
            }
            "\$back" -> backHandler?.invoke()
            "\$close" -> closeHandler?.invoke() ?: backHandler?.invoke()

            "\$util.alert" -> utilityHandler?.invoke(
                UtilityMessage(
                    kind = "alert",
                    title = stringOption(options, "title") ?: "Alert",
                    description = stringOption(options, "description"),
                    text = stringOption(options, "text")
                )
            )
            "\$util.toast" -> utilityHandler?.invoke(
                UtilityMessage(kind = "toast", text = stringOption(options, "text") ?: stringOption(options, "title"))
            )
            "\$util.banner" -> utilityHandler?.invoke(
                UtilityMessage(
                    kind = "banner",
                    title = stringOption(options, "title"),
                    description = stringOption(options, "description"),
                    text = stringOption(options, "text")
                )
            )

            "\$log", "\$log.info" -> logMessage("INFO", options)
            "\$log.debug" -> logMessage("DEBUG", options)
            "\$log.error" -> logMessage("ERROR", options)

            else -> println("[Jasonette] Unknown action: $type")
        }
    }

    private suspend fun networkRequest(
        urlStr: String,
        options: kotlinx.serialization.json.JsonObject?
    ) {
        val body = networkClient?.invoke(urlStr, options) ?: httpNetworkRequest(urlStr, options)
        val responseValue = try {
            JsonValueConverter.jsonElementToAny(kotlinx.serialization.json.Json.parseToJsonElement(body))
        } catch (_: Exception) {
            body
        }
        stateManager.set(mapOf("\$response" to responseValue))
    }

    private fun httpNetworkRequest(
        urlStr: String,
        options: kotlinx.serialization.json.JsonObject?
    ): String {
        val url = URL(urlStr)
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.requestMethod =
                (options?.get("method") as? JsonPrimitive)?.content?.uppercase() ?: "GET"
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000

            val code = conn.responseCode
            if (code !in 200..299) throw ActionException("HTTP error: $code")

            return conn.inputStream.bufferedReader().readText()
        } finally {
            conn.disconnect()
        }
    }

    fun dispatchHref(href: JasonHref) {
        val url = href.url ?: throw ActionException("Missing URL")
        val resolved = resolveAllowedUrl(url)
        navigationHandler?.invoke(href.copy(url = resolved))
    }

    private fun templatedOptions(options: JsonObject?): JsonObject? {
        val context = actionContext()
        return options?.let { renderOptionElement(it, context) as? JsonObject ?: it }
    }

    private fun renderOptionElement(element: JsonElement, context: Map<String, Any?>): JsonElement {
        return when (element) {
            is JsonObject -> JsonObject(
                element.mapKeys { (key, _) -> renderOptionKey(key, context) }
                    .mapValues { (_, value) -> renderOptionElement(value, context) }
            )
            is JsonArray -> JsonArray(element.map { renderOptionElement(it, context) })
            is JsonPrimitive -> {
                if (element.isString && element.content.contains("{{")) {
                    JsonValueConverter.anyToJsonElement(TemplateEngine.render(element.content, context))
                } else {
                    element
                }
            }
            else -> element
        }
    }

    private fun renderOptionKey(key: String, context: Map<String, Any?>): String {
        if (!key.contains("{{")) return key
        return TemplateEngine.render(key, context)?.toString() ?: key
    }

    private fun actionContext(): Map<String, Any?> {
        val local = stateManager.local.toMap()
        val context = local.toMutableMap()
        context["\$get"] = local
        context["\$cache"] = stateManager.cacheGet()
        local["\$response"]?.let { context["\$response"] = it }
        if (!context.containsKey("\$jason")) {
            context["\$jason"] = local
        }
        return context
    }

    private fun hrefFromOptions(options: kotlinx.serialization.json.JsonObject?): JasonHref {
        return JasonHref(
            url = stringOption(options, "url"),
            view = stringOption(options, "view"),
            transition = stringOption(options, "transition")
        )
    }

    private fun stringOption(options: kotlinx.serialization.json.JsonObject?, name: String): String? =
        (options?.get(name) as? JsonPrimitive)?.content

    private fun renderDataOption(options: kotlinx.serialization.json.JsonObject?): Any? =
        options?.get("data")?.let { JsonValueConverter.jsonElementToAny(it) }

    private fun logMessage(level: String, options: kotlinx.serialization.json.JsonObject?) {
        val message = stringOption(options, "text")
            ?: stringOption(options, "message")
            ?: options?.toString()
            ?: ""
        println("[Jasonette][$level] $message")
    }

    private fun resolveAllowedUrl(url: String): String {
        val resolved = try {
            val uri = URI(url)
            if (uri.isAbsolute) uri else baseUrl?.let { URI(it).resolve(uri) }
        } catch (_: Exception) {
            null
        } ?: throw ActionException("Invalid URL")

        val scheme = resolved.scheme?.lowercase()
        if (scheme !in setOf("http", "https")) {
            throw ActionException("URL scheme not allowed")
        }
        return resolved.toString()
    }

    private fun jsonElementToString(element: kotlinx.serialization.json.JsonElement): String {
        return when (element) {
            is JsonPrimitive -> element.content
            else -> element.toString()
        }
    }

    class ActionException(message: String) : Exception(message)
}
