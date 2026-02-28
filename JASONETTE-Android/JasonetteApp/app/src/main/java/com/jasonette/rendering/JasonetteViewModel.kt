package com.jasonette.rendering

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.jasonette.core.*
import com.jasonette.template.TemplateEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

sealed class UiState {
    data object Loading : UiState()
    data class Loaded(val root: JasonRoot) : UiState()
    data class Error(val message: String) : UiState()
}

class JasonetteViewModel(
    application: Application,
    private val url: String? = null,
    private var document: JasonDocument? = null
) : AndroidViewModel(application) {

    private val _uiState = MutableStateFlow<UiState>(UiState.Loading)
    val uiState: StateFlow<UiState> = _uiState

    private val loader = DocumentLoader()
    val stateManager = StateManager(application)
    val actionDispatcher = ActionDispatcher(stateManager)

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    fun loadIfNeeded() {
        if (_uiState.value is UiState.Loading) {
            load()
        }
    }

    fun reload() {
        _uiState.value = UiState.Loading
        load()
    }

    private fun load() {
        viewModelScope.launch {
            try {
                if (document == null && url != null) {
                    document = loader.load(url)
                }
                val doc = document ?: run {
                    _uiState.value = UiState.Error("No document")
                    return@launch
                }
                render(doc)

                // Fire $load lifecycle
                doc.jason.head?.actions?.get("\$load")?.let { loadAction ->
                    actionDispatcher.execute(loadAction)
                    render(doc)
                }
            } catch (e: Exception) {
                _uiState.value = UiState.Error(e.message ?: "Unknown error")
            }
        }
    }

    private fun render(doc: JasonDocument) {
        val head = doc.jason.head
        val data = head?.data?.let { jsonObjectToMap(it) } ?: emptyMap()
        val context = data + stateManager.local

        if (head?.templates?.body != null) {
            val templateValue = jsonElementToAny(head.templates.body)
            val rendered = TemplateEngine.render(templateValue, context)
            try {
                val jsonStr = json.encodeToString(
                    kotlinx.serialization.json.JsonElement.serializer(),
                    anyToJsonElement(rendered)
                )
                val root = json.decodeFromString<JasonRoot>(jsonStr)
                _uiState.value = UiState.Loaded(root.copy(head = head))
            } catch (_: Exception) {
                _uiState.value = UiState.Loaded(doc.jason)
            }
        } else {
            _uiState.value = UiState.Loaded(doc.jason)
        }
    }

    fun handleAction(action: JasonAction) {
        viewModelScope.launch {
            actionDispatcher.execute(action)
        }
    }

    // Helpers

    private fun jsonObjectToMap(obj: JsonObject): Map<String, Any?> {
        return obj.entries.associate { (key, value) -> key to jsonElementToAny(value) }
    }

    private fun jsonElementToAny(element: kotlinx.serialization.json.JsonElement?): Any? {
        if (element == null) return null
        return when (element) {
            is kotlinx.serialization.json.JsonPrimitive -> {
                if (element.isString) element.content
                else element.content.toIntOrNull()
                    ?: element.content.toDoubleOrNull()
                    ?: element.content.toBooleanStrictOrNull()
            }
            is kotlinx.serialization.json.JsonArray -> element.map { jsonElementToAny(it) }
            is kotlinx.serialization.json.JsonObject -> element.entries.associate {
                it.key to jsonElementToAny(it.value)
            }
        }
    }

    private fun anyToJsonElement(value: Any?): kotlinx.serialization.json.JsonElement {
        return when (value) {
            null -> kotlinx.serialization.json.JsonNull
            is String -> kotlinx.serialization.json.JsonPrimitive(value)
            is Int -> kotlinx.serialization.json.JsonPrimitive(value)
            is Double -> kotlinx.serialization.json.JsonPrimitive(value)
            is Boolean -> kotlinx.serialization.json.JsonPrimitive(value)
            is List<*> -> kotlinx.serialization.json.JsonArray(value.map { anyToJsonElement(it) })
            is Map<*, *> -> kotlinx.serialization.json.JsonObject(
                value.entries.associate { it.key.toString() to anyToJsonElement(it.value) }
            )
            else -> kotlinx.serialization.json.JsonPrimitive(value.toString())
        }
    }
}
