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
        datePicker = ::requestDatePicker
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

    fun selectPickerItem(index: Int) {
        val request = _nativeUiRequest.value as? NativeUiRequest.Picker ?: return
        if (!request.deferred.isCompleted) request.deferred.complete(ActionDispatcher.PickerSelection(index))
    }

    fun completeDatePicker(value: Long) {
        val request = _nativeUiRequest.value as? NativeUiRequest.DatePicker ?: return
        if (!request.deferred.isCompleted) request.deferred.complete(value)
    }

    fun cancelNativeUiRequest() {
        when (val request = _nativeUiRequest.value) {
            is NativeUiRequest.Picker -> if (!request.deferred.isCompleted) request.deferred.complete(null)
            is NativeUiRequest.DatePicker -> if (!request.deferred.isCompleted) request.deferred.complete(null)
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

    override fun onCleared() {
        timerScheduler.stop()
        audioPlayer.release()
        super.onCleared()
    }

    // Helpers
}
