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
    val actionDispatcher = ActionDispatcher(stateManager, baseUrl = url)
    private var navigationHandler: ((JasonHref) -> Unit)? = null

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    init {
        actionDispatcher.setRenderHandler { renderCurrentDocument() }
        actionDispatcher.setReloadHandler { reload() }
        actionDispatcher.setNavigationHandler { href -> navigationHandler?.invoke(href) }
        actionDispatcher.setActionResolver { name -> document?.jason?.head?.actions?.get(name) }
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
                    actionDispatcher.setBaseUrl(url)
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
        val context = renderContext(data)

        if (head?.templates?.body != null) {
            val templateValue = JsonValueConverter.jsonElementToAny(head.templates.body)
            val rendered = TemplateEngine.render(templateValue, context)
            try {
                val jsonStr = json.encodeToString(
                    kotlinx.serialization.json.JsonElement.serializer(),
                    JsonValueConverter.anyToJsonElement(rendered)
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
            if (action.type != "\$reload") {
                renderCurrentDocument()
            }
        }
    }

    fun handleHref(href: JasonHref) {
        try {
            actionDispatcher.dispatchHref(href)
        } catch (_: Exception) {
            // Drop unsafe or malformed navigation requests.
        }
    }

    fun setNavigationHandler(handler: ((JasonHref) -> Unit)?) {
        navigationHandler = handler
    }

    private fun renderCurrentDocument() {
        document?.let { render(it) }
    }

    private fun renderContext(data: Map<String, Any?>): Map<String, Any?> {
        val context = (data + stateManager.local).toMutableMap()
        if (!context.containsKey("\$jason")) {
            context["\$jason"] = data
        }
        context["\$get"] = stateManager.local.toMap()
        context["\$cache"] = stateManager.cacheGet()
        stateManager.local["\$response"]?.let { context["\$response"] = it }
        return context
    }

    // Helpers

    private fun jsonObjectToMap(obj: JsonObject): Map<String, Any?> {
        return obj.entries.associate { (key, value) -> key to JsonValueConverter.jsonElementToAny(value) }
    }
}
