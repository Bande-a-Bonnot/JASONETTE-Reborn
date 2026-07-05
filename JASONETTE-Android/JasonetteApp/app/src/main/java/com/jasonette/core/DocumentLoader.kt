package com.jasonette.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import java.net.HttpURLConnection
import java.net.URL

/**
 * Loads and decodes $jason documents from URLs or strings.
 */
class DocumentLoader(
    private val fetcher: suspend (String) -> LoadedJson = { url -> defaultFetch(url) }
) {
    data class LoadedJson(val body: String, val url: String)

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    /** Load a document from a URL, resolving legacy Jasonette include directives first. */
    suspend fun load(url: String): JasonDocument = withContext(Dispatchers.IO) {
        if (!isAllowedHttpUrl(url)) {
            throw DocumentException("Blocked URL scheme")
        }
        val loaded = fetcher(url)
        if (!isAllowedHttpUrl(loaded.url)) {
            throw DocumentException("Blocked URL scheme")
        }
        val raw = json.parseToJsonElement(loaded.body)
        val resolved = resolveLegacyIncludes(raw, raw, loaded.url)
        decode(json.encodeToString(JsonElement.serializer(), resolved))
    }

    /** Decode a document from a JSON string. */
    fun decode(jsonStr: String): JasonDocument {
        return json.decodeFromString<JasonDocument>(jsonStr)
    }

    private suspend fun resolveLegacyIncludes(
        value: JsonElement,
        root: JsonElement,
        baseUrl: String,
        includeDepth: Int = 0,
        includeStack: Set<String> = emptySet()
    ): JsonElement {
        return when (value) {
            is JsonArray -> JsonArray(
                value.map { child ->
                    resolveLegacyIncludes(child, root, baseUrl, includeDepth, includeStack.toSet())
                }
            )
            is JsonObject -> {
                val includeRef = (value["+"] as? JsonPrimitive)?.contentOrNull
                    ?: (value["@"] as? JsonPrimitive)?.contentOrNull
                if (includeRef != null) {
                    resolveIncludeObject(value, root, baseUrl, includeRef, includeDepth, includeStack)
                } else {
                    JsonObject(
                        value.mapValues { (_, child) ->
                            resolveLegacyIncludes(child, root, baseUrl, includeDepth, includeStack.toSet())
                        }
                    )
                }
            }
            else -> value
        }
    }

    private suspend fun resolveIncludeObject(
        value: JsonObject,
        root: JsonElement,
        baseUrl: String,
        includeRef: String,
        includeDepth: Int,
        includeStack: Set<String>
    ): JsonElement {
        val rest = value.filterKeys { it != "+" && it != "@" }
        var included: JsonElement = JsonNull
        var includeBaseUrl = baseUrl
        var nextRoot = root
        var nextStack = includeStack

        if (includeDepth < MAX_INCLUDE_DEPTH) {
            if (includeRef.startsWith("\$document")) {
                val localKey = "local:$includeRef@$baseUrl"
                if (!includeStack.contains(localKey)) {
                    included = resolveDocumentPath(root, includeRef) ?: JsonNull
                    nextStack = includeStack + localKey
                }
            } else {
                val fetched = fetchInclude(includeRef, baseUrl)
                if (fetched != null && !includeStack.contains(fetched.key)) {
                    included = fetched.value
                    includeBaseUrl = fetched.url
                    nextRoot = fetched.root
                    nextStack = includeStack + fetched.key
                }
            }
        }

        val merged = mergeIncluded(included, rest)
        if (value === root) {
            nextRoot = merged
        }
        return resolveLegacyIncludes(merged, nextRoot, includeBaseUrl, includeDepth + 1, nextStack)
    }

    private suspend fun fetchInclude(ref: String, baseUrl: String): IncludeResult? {
        val (selector, urlRef) = selectorInclude(ref)
        val resolvedUrl = includeUrl(urlRef, baseUrl) ?: return null
        val loaded = fetcher(resolvedUrl)
        val finalUrl = loaded.url.ifBlank { resolvedUrl }
        if (!isAllowedHttpUrl(finalUrl)) return null

        val fetched = json.parseToJsonElement(loaded.body)
        val value = if (selector == null) {
            fetched
        } else {
            (fetched as? JsonObject)?.get(selector) ?: JsonNull
        }
        return IncludeResult(value = value, root = fetched, url = finalUrl, key = "${selector ?: ""}@$finalUrl")
    }

    private fun resolveDocumentPath(root: JsonElement, ref: String): JsonElement? {
        if (ref == "\$document") return root
        if (!ref.startsWith("\$document.")) return null

        var current: JsonElement = root
        for (part in ref.removePrefix("\$document.").split('.')) {
            if (part.isEmpty()) continue
            current = (current as? JsonObject)?.get(part) ?: return null
        }
        return current
    }

    private fun mergeIncluded(included: JsonElement, rest: Map<String, JsonElement>): JsonElement {
        if (rest.isEmpty()) return included
        return if (included is JsonObject) {
            JsonObject(included + rest)
        } else {
            JsonObject(mapOf("value" to included) + rest)
        }
    }

    private data class IncludeResult(val value: JsonElement, val root: JsonElement, val url: String, val key: String)

    class DocumentException(message: String) : Exception(message)

    companion object {
        private const val MAX_INCLUDE_DEPTH = 8

        private suspend fun defaultFetch(url: String): LoadedJson = withContext(Dispatchers.IO) {
            val conn = URL(url).openConnection() as HttpURLConnection
            try {
                conn.requestMethod = "GET"
                conn.connectTimeout = 10_000
                conn.readTimeout = 10_000

                val code = conn.responseCode
                if (code !in 200..299) {
                    throw DocumentException("HTTP error: $code")
                }

                LoadedJson(
                    body = conn.inputStream.bufferedReader().readText(),
                    url = conn.url?.toString() ?: url
                )
            } finally {
                conn.disconnect()
            }
        }

        private fun isAllowedHttpUrl(url: String): Boolean = try {
            val protocol = URL(url).protocol.lowercase()
            protocol == "http" || protocol == "https"
        } catch (_: Exception) {
            false
        }

        private fun includeUrl(ref: String, baseUrl: String): String? = try {
            val resolved = URL(URL(baseUrl), ref).toString()
            if (isAllowedHttpUrl(resolved)) resolved else null
        } catch (_: Exception) {
            null
        }

        private fun selectorInclude(ref: String): Pair<String?, String> {
            val at = ref.indexOf('@')
            val selectorCandidate = if (at > 0) ref.substring(0, at) else ""
            return if (at > 0 && selectorCandidate.none { it == ':' || it == '/' || it == '?' || it == '#' }) {
                selectorCandidate to ref.substring(at + 1)
            } else {
                null to ref
            }
        }
    }
}
