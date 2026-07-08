package com.jasonette.rendering

import com.jasonette.core.*
import com.jasonette.template.TemplateEngine
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.decodeFromJsonElement
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

/**
 * Executes Jasonette actions with success/error chaining.
 */
class ActionDispatcher(
    private val stateManager: StateManager,
    private var baseUrl: String? = null,
    private val timerScheduler: JasonTimerScheduler = CoroutineJasonTimerScheduler(),
    private val geolocationProvider: (suspend () -> String)? = null,
    private val audioPlayer: (suspend (String) -> Unit)? = null,
    private val audioPauser: (suspend () -> Unit)? = null,
    private val audioStopper: (suspend () -> Unit)? = null,
    private val mediaPlayback: (suspend (String) -> Unit)? = null,
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
    private val actionJson = Json { ignoreUnknownKeys = true; isLenient = true }

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
            executeAction(action)
        } catch (_: LambdaReturn) {
            // A top-level $return has no caller to resume.
        }
    }

    private suspend fun executeAction(action: JasonAction) {
        try {
            dispatch(action)
            executeContinuations(action, success = true)
        } catch (ret: LambdaReturn) {
            throw ret
        } catch (_: Exception) {
            executeContinuations(action, success = false)
        }
    }

    private suspend fun executeContinuations(action: JasonAction, success: Boolean) {
        val raw = if (success) action.successElement else action.errorElement
        if (raw != null) {
            executeContinuationElement(raw)
            return
        }
        val fallback = if (success) action.successActions else action.errorActions
        fallback.forEach { executeAction(it) }
    }

    private suspend fun executeContinuationElement(element: JsonElement) {
        when (element) {
            is JsonArray -> executeContinuationArray(element)
            is JsonObject -> decodeActionOrNull(element)?.let { executeAction(it) }
            else -> {}
        }
    }

    private suspend fun executeContinuationArray(actions: JsonArray) {
        var index = 0
        while (index < actions.size) {
            val current = actions[index]
            val conditionalChain = if (isConditionalStartObject(current)) {
                collectConditionalChain(actions, index)
            } else null

            if (conditionalChain != null) {
                executeRenderedContinuation(conditionalChain)
                index += conditionalChain.size
                continue
            }

            if (isConditionalContinuationObject(current)) {
                index++
                continue
            }

            executeContinuationElement(current)
            index++
        }
    }

    private suspend fun executeRenderedContinuation(elements: List<JsonElement>) {
        val rendered = JsonValueConverter.anyToJsonElement(
            TemplateEngine.render(JsonValueConverter.jsonElementToAny(JsonArray(elements)), actionContext())
        )
        executeContinuationElement(rendered)
    }

    private fun isConditionalStartObject(element: JsonElement): Boolean =
        element is JsonObject && element.keys.any { it.startsWith("{{#if ") && it.endsWith("}}") }

    private fun isConditionalContinuationObject(element: JsonElement): Boolean =
        element is JsonObject && element.isNotEmpty() && element.keys.all { key ->
            (key.startsWith("{{#elseif ") && key.endsWith("}}")) || key == "{{#else}}"
        }

    private fun collectConditionalChain(actions: JsonArray, start: Int): List<JsonElement> {
        val chain = mutableListOf<JsonElement>(actions[start])
        var index = start + 1
        while (index < actions.size) {
            val next = actions[index]
            if (!isConditionalContinuationObject(next)) break
            chain.add(next)
            if ((next as? JsonObject)?.containsKey("{{#else}}") == true) break
            index++
        }
        return chain
    }

    private fun decodeActionOrNull(element: JsonElement): JasonAction? =
        runCatching { actionJson.decodeFromJsonElement(JasonAction.serializer(), element) }.getOrNull()

    private suspend fun dispatch(action: JasonAction) {
        val optionElement = templatedOptions(action.options)
        if (action.type == null) {
            action.trigger?.let { trigger ->
                executeTrigger(trigger, optionElement)
            }
            return
        }
        val type = action.type ?: return
        val options = optionElement as? JsonObject

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

            "\$timer.start" -> startTimer(options)
            "\$timer.stop" -> timerScheduler.stop(stringOption(options, "name"))

            "\$lambda" -> executeLambda(optionElement)
            "\$return.success" -> throw LambdaReturn(success = true, payload = returnPayload(optionElement))
            "\$return.error" -> throw LambdaReturn(success = false, payload = returnPayload(optionElement))

            "\$convert.csv" -> convertCsvAction(options)
            "\$convert.rss" -> convertRssAction(options)
            "\$geo.get" -> geoGet()
            "\$audio.play" -> audioPlay(options)
            "\$audio.pause" -> audioPause()
            "\$audio.stop" -> audioStop()
            "\$media.play" -> mediaPlay(options)

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

    private fun startTimer(options: kotlinx.serialization.json.JsonObject?) {
        val name = stringOption(options, "name") ?: throw ActionException("Missing timer name")
        val intervalSeconds = stringOption(options, "interval")?.toDoubleOrNull()
            ?: throw ActionException("Missing timer interval")
        if (intervalSeconds <= 0) throw ActionException("Timer interval must be greater than zero")
        val actionElement = options?.get("action") as? JsonObject
            ?: throw ActionException("Missing timer action")
        val timerAction = actionJson.decodeFromJsonElement(JasonAction.serializer(), actionElement)
        val repeats = stringOption(options, "repeats")?.toBooleanStrictOrNull() ?: true

        timerScheduler.start(name, (intervalSeconds * 1000).toLong().coerceAtLeast(1), repeats) {
            execute(timerAction)
        }
    }

    private suspend fun executeTrigger(trigger: String, options: JsonElement?) {
        val payload = options?.let { JsonValueConverter.jsonElementToAny(it) }
        var returned: LambdaReturn? = null
        withTemporaryJason(payload) {
            actionResolver?.invoke(trigger)?.let { action ->
                try {
                    executeAction(action)
                } catch (ret: LambdaReturn) {
                    returned = ret
                }
            }
        }
        returned?.let { ret ->
            setJasonPayload(ret.payload)
            if (!ret.success) throw ActionException("Trigger returned error")
        }
    }

    private suspend fun executeLambda(options: JsonElement?) {
        val lambdaOptions = lambdaOptionsObject(options) ?: return
        val name = stringOption(lambdaOptions, "name")
        if (name == null) {
            decodeActionOrNull(lambdaOptions)?.let { executeAction(it) }
            return
        }
        val payload = lambdaOptions["options"]?.let { JsonValueConverter.jsonElementToAny(it) }
        var returned: LambdaReturn? = null
        withTemporaryJason(payload) {
            actionResolver?.invoke(name)?.let { action ->
                try {
                    executeAction(action)
                } catch (ret: LambdaReturn) {
                    returned = ret
                }
            }
        }
        returned?.let { ret ->
            setJasonPayload(ret.payload)
            if (!ret.success) throw ActionException("Lambda returned error")
        }
    }

    private fun returnPayload(options: JsonElement?): Any? =
        options?.let { JsonValueConverter.jsonElementToAny(it) } ?: stateManager.local["\$jason"]

    private fun setJasonPayload(payload: Any?) {
        stateManager.local["\$jason"] = payload
    }

    private suspend fun withTemporaryJason(payload: Any?, block: suspend () -> Unit) {
        if (payload == null) {
            block()
            return
        }
        val hadPrevious = stateManager.local.containsKey("\$jason")
        val previous = stateManager.local["\$jason"]
        stateManager.local["\$jason"] = payload
        try {
            block()
        } finally {
            if (hadPrevious) {
                stateManager.local["\$jason"] = previous
            } else {
                stateManager.local.remove("\$jason")
            }
        }
    }

    private fun lambdaOptionsObject(options: JsonElement?): JsonObject? = when (options) {
        is JsonObject -> options
        is JsonArray -> options.firstOrNull { it is JsonObject } as? JsonObject
        else -> null
    }

    private fun convertCsvAction(options: JsonObject?) {
        stateManager.set(mapOf("\$jason" to convertCsv(conversionInput(options))))
    }

    private fun convertRssAction(options: JsonObject?) {
        stateManager.set(mapOf("\$jason" to convertRss(conversionInput(options))))
    }

    private fun conversionInput(options: JsonObject?): String =
        stringOption(options, "data") ?: (stateManager.local["\$jason"] as? String) ?: ""

    private fun convertCsv(text: String): List<Map<String, String>> {
        val rows = parseCsvRows(text)
        val headers = rows.firstOrNull()?.map { it.trim() } ?: return emptyList()
        return rows.drop(1).mapNotNull { row ->
            if (row.none { it.trim().isNotEmpty() }) return@mapNotNull null
            buildMap {
                headers.forEachIndexed { index, header ->
                    if (header.isNotEmpty()) put(header, row.getOrElse(index) { "" }.trim())
                }
            }
        }
    }

    private fun parseCsvRows(text: String): List<List<String>> {
        val rows = mutableListOf<List<String>>()
        val row = mutableListOf<String>()
        val field = StringBuilder()
        var inQuotes = false
        var index = 0
        while (index < text.length) {
            val char = text[index]
            when {
                char == '"' && inQuotes && text.getOrNull(index + 1) == '"' -> {
                    field.append('"')
                    index++
                }
                char == '"' -> inQuotes = !inQuotes
                char == ',' && !inQuotes -> {
                    row.add(field.toString())
                    field.clear()
                }
                char == '\n' && !inQuotes -> {
                    row.add(field.toString())
                    rows.add(row.toList())
                    row.clear()
                    field.clear()
                }
                char != '\r' || inQuotes -> field.append(char)
            }
            index++
        }
        if (field.isNotEmpty() || row.isNotEmpty()) {
            row.add(field.toString())
            rows.add(row.toList())
        }
        return rows
    }

    private fun convertRss(text: String): List<Map<String, Any>> {
        val itemRegex = Regex("(?is)<item\\b[^>]*>(.*?)</item>")
        return itemRegex.findAll(text).mapNotNull { match ->
            val item = match.groupValues[1]
            buildMap<String, Any> {
                firstXmlValue("title", item)?.let { put("title", it) }
                (firstXmlValue("dc:creator", item) ?: firstXmlValue("author", item))?.let { put("author", it) }
                firstXmlValue("description", item)?.let { put("description", it) }
                firstXmlValue("link", item)?.let { put("url", it) }
                val imageUrl = firstXmlAttribute("url", "(?is)<media:(?:content|thumbnail)\\b[^>]*>", item)
                    ?: firstXmlAttribute("href", "(?is)<enclosure\\b[^>]*>", item)
                    ?: firstXmlAttribute("url", "(?is)<enclosure\\b[^>]*>", item)
                imageUrl?.let { put("image", mapOf("url" to it)) }
            }.takeIf { it.isNotEmpty() }
        }.toList()
    }

    private fun firstXmlValue(name: String, text: String): String? {
        val escaped = Regex.escape(name)
        val regex = Regex("(?is)<$escaped\\b[^>]*>(?:<!\\[CDATA\\[(.*?)]]>|(.*?))</$escaped>")
        val match = regex.find(text) ?: return null
        val value = match.groups[1]?.value ?: match.groups[2]?.value ?: return null
        return decodeXmlEntities(value.trim())
    }

    private fun firstXmlAttribute(name: String, tagPattern: String, text: String): String? {
        val tag = Regex(tagPattern).find(text)?.value ?: return null
        val attr = Regex("\\b${Regex.escape(name)}\\s*=\\s*[\"']([^\"']+)[\"']").find(tag)?.groupValues?.get(1)
            ?: return null
        return decodeXmlEntities(attr)
    }

    private fun decodeXmlEntities(value: String): String = value
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&#39;", "'")

    private suspend fun geoGet() {
        val coord = geolocationProvider?.invoke() ?: throw ActionException("Location unavailable")
        val payload = mapOf("coord" to coord, "value" to coord)
        stateManager.set(payload + mapOf("\$jason" to payload))
    }

    private suspend fun audioPlay(options: JsonObject?) {
        val url = stringOption(options, "url") ?: throw ActionException("Missing audio URL")
        audioPlayer?.invoke(resolveAllowedUrl(url)) ?: throw ActionException("Audio playback unavailable")
    }

    private suspend fun audioPause() {
        audioPauser?.invoke() ?: throw ActionException("Audio pause unavailable")
    }

    private suspend fun audioStop() {
        audioStopper?.invoke() ?: throw ActionException("Audio stop unavailable")
    }

    private suspend fun mediaPlay(options: JsonObject?) {
        val url = stringOption(options, "url") ?: throw ActionException("Missing media URL")
        mediaPlayback?.invoke(resolveAllowedUrl(url)) ?: throw ActionException("Media playback unavailable")
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
        stateManager.set(mapOf("\$response" to responseValue, "\$jason" to responseValue))
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

    private fun templatedOptions(options: JsonElement?): JsonElement? = options?.let {
        JsonValueConverter.anyToJsonElement(
            TemplateEngine.render(JsonValueConverter.jsonElementToAny(it), actionContext())
        )
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

    private class LambdaReturn(val success: Boolean, val payload: Any?) : RuntimeException()

    class ActionException(message: String) : Exception(message)
}
