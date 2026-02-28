package com.jasonette.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

/**
 * Loads and decodes $jason documents from URLs or strings.
 */
class DocumentLoader {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    /** Load a document from a URL. */
    suspend fun load(url: String): JasonDocument = withContext(Dispatchers.IO) {
        val conn = URL(url).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "GET"
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000

            val code = conn.responseCode
            if (code !in 200..299) {
                throw DocumentException("HTTP error: $code")
            }

            val body = conn.inputStream.bufferedReader().readText()
            decode(body)
        } finally {
            conn.disconnect()
        }
    }

    /** Decode a document from a JSON string. */
    fun decode(jsonStr: String): JasonDocument {
        return json.decodeFromString<JasonDocument>(jsonStr)
    }

    class DocumentException(message: String) : Exception(message)
}
