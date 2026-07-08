package com.jasonette.rendering

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.jasonette.core.*
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

sealed class UiState {
    data object Loading : UiState()
    data class Loaded(val root: JasonRoot) : UiState()
    data class Error(val message: String) : UiState()
}

sealed class NativeUiRequest {
    data class Picker(
        val request: ActionDispatcher.PickerRequest,
        val deferred: CompletableDeferred<ActionDispatcher.PickerSelection?>
    ) : NativeUiRequest()

    data class DatePicker(
        val request: ActionDispatcher.DatePickerRequest,
        val deferred: CompletableDeferred<Long?>
    ) : NativeUiRequest()

    data class VisionScan(
        val request: ActionDispatcher.VisionScanRequest,
        val deferred: CompletableDeferred<Map<String, Any>?>
    ) : NativeUiRequest()
}

class JasonetteViewModel(
    application: Application,
    private val url: String? = null,
    private var document: JasonDocument? = null
) : AndroidViewModel(application) {

    private val _uiState = MutableStateFlow<UiState>(UiState.Loading)
    val uiState: StateFlow<UiState> = _uiState

    private val _utilityMessages = MutableSharedFlow<ActionDispatcher.UtilityMessage>(extraBufferCapacity = 16)
    val utilityMessages: SharedFlow<ActionDispatcher.UtilityMessage> = _utilityMessages.asSharedFlow()

    private val _nativeUiRequest = MutableStateFlow<NativeUiRequest?>(null)
    val nativeUiRequest: StateFlow<NativeUiRequest?> = _nativeUiRequest

    private val loader = DocumentLoader()
    val stateManager = StateManager(application)
    private val timerScheduler = CoroutineJasonTimerScheduler(viewModelScope)
    private val geolocationProvider = AndroidGeolocationProvider(application)
    private val addressBookProvider = AndroidAddressBookProvider(application)
    private val audioPlayer = AndroidAudioPlayer()
    private val mediaPlayback = AndroidMediaPlayback(application)
    private val shareHandler = AndroidShareHandler(application)
    val actionDispatcher = ActionDispatcher(
        stateManager,
        baseUrl = url,
        timerScheduler = timerScheduler,
        geolocationProvider = geolocationProvider::currentCoordinate,
        audioPlayer = audioPlayer::play,
        audioPauser = audioPlayer::pause,
        audioStopper = audioPlayer::stop,
        audioDurationProvider = audioPlayer::duration,
        audioPositionProvider = audioPlayer::position,
        audioSeeker = audioPlayer::seek,
        mediaPlayback = mediaPlayback::play,
        shareHandler = shareHandler::share,
        addressBookProvider = addressBookProvider::contacts,
        utilityPicker = ::requestPicker,
        datePicker = ::requestDatePicker,
        visionScanner = ::requestVisionScan
    )
    private var navigationHandler: ((JasonHref) -> Unit)? = null
    private var backHandler: (() -> Unit)? = null
    private var closeHandler: (() -> Unit)? = null

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }
    private val documentRenderer = JasonetteDocumentRenderer(stateManager, json)
    private val renderSelection = RenderSelection()

    init {
        actionDispatcher.setRenderHandler { templateName, renderData, hasRenderData ->
            renderSelection.apply(templateName, renderData, hasRenderData)
            renderCurrentDocument()
        }
        actionDispatcher.setReloadHandler { reload() }
        actionDispatcher.setNavigationHandler { href -> navigationHandler?.invoke(href) }
        actionDispatcher.setBackHandler { backHandler?.invoke() }
        actionDispatcher.setCloseHandler { closeHandler?.invoke() ?: backHandler?.invoke() }
        actionDispatcher.setActionResolver { name -> document?.jason?.head?.actions?.get(name) }
        actionDispatcher.setUtilityHandler { message -> _utilityMessages.tryEmit(message) }
    }

    fun loadIfNeeded() {
        if (_uiState.value is UiState.Loading) {
            load()
        }
    }

    fun reload() {
        renderSelection.reset()
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
                fireVisionReadyIfNeeded(doc)
            } catch (e: Exception) {
                _uiState.value = UiState.Error(e.message ?: "Unknown error")
            }
        }
    }

    private fun render(doc: JasonDocument) {
        _uiState.value = UiState.Loaded(
            documentRenderer.render(
                doc,
                renderSelection.templateName,
                renderSelection.renderData,
                renderSelection.hasRenderData
            )
        )
    }

    fun handleAction(action: JasonAction) {
        viewModelScope.launch {
            actionDispatcher.execute(action)
            if (action.type != "\$reload") {
                renderCurrentDocument()
            }
        }
    }

    private suspend fun requestPicker(request: ActionDispatcher.PickerRequest): ActionDispatcher.PickerSelection? {
        val deferred = CompletableDeferred<ActionDispatcher.PickerSelection?>()
        val nativeRequest = NativeUiRequest.Picker(request, deferred)
        _nativeUiRequest.value = nativeRequest
        return try {
            deferred.await()
        } finally {
            if (_nativeUiRequest.value === nativeRequest) _nativeUiRequest.value = null
        }
    }

    private suspend fun requestDatePicker(request: ActionDispatcher.DatePickerRequest): Long? {
        val deferred = CompletableDeferred<Long?>()
        val nativeRequest = NativeUiRequest.DatePicker(request, deferred)
        _nativeUiRequest.value = nativeRequest
        return try {
            deferred.await()
        } finally {
            if (_nativeUiRequest.value === nativeRequest) _nativeUiRequest.value = null
        }
    }

    private suspend fun requestVisionScan(request: ActionDispatcher.VisionScanRequest): Map<String, Any>? {
        val deferred = CompletableDeferred<Map<String, Any>?>()
        val nativeRequest = NativeUiRequest.VisionScan(request, deferred)
        _nativeUiRequest.value = nativeRequest
        return try {
            deferred.await()
        } finally {
            if (_nativeUiRequest.value === nativeRequest) _nativeUiRequest.value = null
        }
    }

    fun selectPickerItem(index: Int) {
        val request = _nativeUiRequest.value as? NativeUiRequest.Picker ?: return
        if (!request.deferred.isCompleted) request.deferred.complete(ActionDispatcher.PickerSelection(index))
    }

    fun completeDatePicker(value: Long) {
        val request = _nativeUiRequest.value as? NativeUiRequest.DatePicker ?: return
        if (!request.deferred.isCompleted) request.deferred.complete(value)
    }

    fun completeVisionScan(payload: Map<String, Any>) {
        completeVisionScan(_nativeUiRequest.value as? NativeUiRequest.VisionScan, payload)
    }

    fun completeVisionScan(request: NativeUiRequest.VisionScan?, payload: Map<String, Any>) {
        if (_nativeUiRequest.value !== request) return
        if (request != null && !request.deferred.isCompleted) request.deferred.complete(payload)
    }

    fun cancelNativeUiRequest() {
        cancelNativeUiRequest(_nativeUiRequest.value)
    }

    fun cancelNativeUiRequest(request: NativeUiRequest?) {
        if (_nativeUiRequest.value !== request) return
        when (request) {
            is NativeUiRequest.Picker -> if (!request.deferred.isCompleted) request.deferred.complete(null)
            is NativeUiRequest.DatePicker -> if (!request.deferred.isCompleted) request.deferred.complete(null)
            is NativeUiRequest.VisionScan -> if (!request.deferred.isCompleted) request.deferred.complete(null)
            null -> {}
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

    fun setBackHandler(handler: (() -> Unit)?) {
        backHandler = handler
    }

    fun setCloseHandler(handler: (() -> Unit)?) {
        closeHandler = handler
    }

    private fun renderCurrentDocument() {
        document?.let { render(it) }
    }

    private suspend fun fireVisionReadyIfNeeded(doc: JasonDocument) {
        val root = (_uiState.value as? UiState.Loaded)?.root ?: return
        if (!bodyHasCameraBackground(root.body)) return
        val readyAction = doc.jason.head?.actions?.get("\$vision.ready") ?: return
        actionDispatcher.execute(readyAction)
        render(doc)
    }

    override fun onCleared() {
        timerScheduler.stop()
        audioPlayer.release()
        super.onCleared()
    }

    // Helpers
}

fun bodyHasCameraBackground(body: JasonBody?): Boolean =
    (body?.background as? JsonPrimitive)?.content == "camera" ||
        ((body?.background as? JsonObject)?.get("type") as? JsonPrimitive)?.content == "camera" ||
        (body?.style?.get("background") as? JsonPrimitive)?.content == "camera" ||
        ((body?.style?.get("background") as? JsonObject)?.get("type") as? JsonPrimitive)?.content == "camera"
