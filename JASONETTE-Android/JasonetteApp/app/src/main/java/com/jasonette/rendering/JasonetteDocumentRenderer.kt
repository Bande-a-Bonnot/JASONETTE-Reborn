package com.jasonette.rendering

import com.jasonette.core.JasonBody
import com.jasonette.core.JasonDocument
import com.jasonette.core.JasonRoot
import com.jasonette.core.JsonValueConverter
import com.jasonette.core.StateManager
import com.jasonette.template.TemplateEngine
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

/**
 * Pure document rendering runtime used by the ViewModel and unit tests.
 *
 * Keeping template/context rendering out of AndroidViewModel lets the Android
 * runtime parity tests exercise $jason/$get/$cache/$response behavior without
 * requiring a device or Robolectric.
 */
class JasonetteDocumentRenderer(
    private val stateManager: StateManager,
    private val json: Json = Json { ignoreUnknownKeys = true; isLenient = true }
) {
    fun render(document: JasonDocument): JasonRoot {
        val root = document.jason
        val head = root.head
        val data = head?.data?.let { jsonObjectToMap(it) } ?: emptyMap()
        val template = head?.templates?.body ?: return root

        val rendered = TemplateEngine.render(
            JsonValueConverter.jsonElementToAny(template),
            renderContext(data)
        )

        val renderedElement = JsonValueConverter.anyToJsonElement(rendered)
        val jsonStr = json.encodeToString(JsonElement.serializer(), renderedElement)
        return try {
            if (renderedElement is JsonObject && ("body" in renderedElement || "head" in renderedElement)) {
                json.decodeFromString<JasonRoot>(jsonStr).copy(head = head)
            } else {
                val body = json.decodeFromString<JasonBody>(jsonStr)
                root.copy(head = head, body = body)
            }
        } catch (_: Exception) {
            root
        }
    }

    internal fun renderContext(data: Map<String, Any?>): Map<String, Any?> {
        val context = (data + stateManager.local).toMutableMap()
        if (!context.containsKey("\$jason")) {
            context["\$jason"] = data
        }
        context["\$get"] = stateManager.local.toMap()
        context["\$cache"] = stateManager.cacheGet()
        stateManager.local["\$response"]?.let { context["\$response"] = it }
        return context
    }

    private fun jsonObjectToMap(obj: JsonObject): Map<String, Any?> =
        obj.entries.associate { (key, value) -> key to JsonValueConverter.jsonElementToAny(value) }
}
