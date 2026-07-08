package com.jasonette.rendering

import android.app.Application
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jasonette.components.ComponentView
import com.jasonette.components.parseCssColor
import com.jasonette.core.*
import kotlinx.serialization.json.JsonPrimitive
import java.util.Calendar

/**
 * Main composable that renders a complete Jasonette document.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JasonetteScreen(
    viewModel: JasonetteViewModel,
    onNavigate: ((JasonHref) -> Unit)? = null,
    onBack: (() -> Unit)? = null,
    onClose: (() -> Unit)? = null
) {
    val uiState by viewModel.uiState.collectAsState()
    val nativeUiRequest by viewModel.nativeUiRequest.collectAsState()
    val currentNativeUiRequest by rememberUpdatedState(nativeUiRequest)
    val snackbarHostState = remember { SnackbarHostState() }
    val context = LocalContext.current
    var alertMessage by remember { mutableStateOf<ActionDispatcher.UtilityMessage?>(null) }
    var pendingPhotoRequestId by rememberSaveable { mutableStateOf<String?>(null) }
    var pendingVideoRequestId by rememberSaveable { mutableStateOf<String?>(null) }
    var pendingImagePickerRequestId by rememberSaveable { mutableStateOf<String?>(null) }
    var pendingVideoPickerRequestId by rememberSaveable { mutableStateOf<String?>(null) }
    val photoCaptureLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        val pendingId = pendingPhotoRequestId.also { pendingPhotoRequestId = null }
        val request = (currentNativeUiRequest as? NativeUiRequest.MediaCapture)?.takeIf { it.id == pendingId }
        val uri = request?.outputUri?.let(Uri::parse)
        if (success && request != null && uri != null) {
            runCatching { androidMediaCapturePayload(context, request.request, uri) }
                .onSuccess { viewModel.completeMediaCapture(request, it) }
                .onFailure { viewModel.cancelNativeUiRequest(request) }
        } else if (request != null) {
            viewModel.cancelNativeUiRequest(request)
        }
    }
    val videoCaptureLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CaptureVideo()) { success ->
        val pendingId = pendingVideoRequestId.also { pendingVideoRequestId = null }
        val request = (currentNativeUiRequest as? NativeUiRequest.MediaCapture)?.takeIf { it.id == pendingId }
        val uri = request?.outputUri?.let(Uri::parse)
        if (success && request != null && uri != null) {
            viewModel.completeMediaCapture(request, androidMediaCapturePayload(context, request.request, uri))
        } else if (request != null) {
            viewModel.cancelNativeUiRequest(request)
        }
    }
    val imagePickerLauncher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        val pendingId = pendingImagePickerRequestId.also { pendingImagePickerRequestId = null }
        val request = (currentNativeUiRequest as? NativeUiRequest.MediaCapture)?.takeIf { it.id == pendingId }
        if (request != null && uri != null) {
            runCatching { androidMediaCapturePayload(context, request.request, uri) }
                .onSuccess { viewModel.completeMediaCapture(request, it) }
                .onFailure { viewModel.cancelNativeUiRequest(request) }
        } else if (request != null) {
            viewModel.cancelNativeUiRequest(request)
        }
    }
    val videoPickerLauncher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        val pendingId = pendingVideoPickerRequestId.also { pendingVideoPickerRequestId = null }
        val request = (currentNativeUiRequest as? NativeUiRequest.MediaCapture)?.takeIf { it.id == pendingId }
        if (request != null && uri != null) {
            viewModel.completeMediaCapture(request, androidMediaCapturePayload(context, request.request, uri))
        } else if (request != null) {
            viewModel.cancelNativeUiRequest(request)
        }
    }

    LaunchedEffect(viewModel, onNavigate, onBack, onClose) {
        viewModel.setNavigationHandler(onNavigate)
        viewModel.setBackHandler(onBack)
        viewModel.setCloseHandler(onClose)
    }

    when (val state = uiState) {
        is UiState.Loading -> {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        is UiState.Error -> {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(state.message, color = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.height(16.dp))
                    Button(onClick = { viewModel.reload() }) {
                        Text("Retry")
                    }
                }
            }
        }
        is UiState.Loaded -> {
            val root = state.root
            val head = root.head
            val body = root.body
            val headStyles = head?.styles ?: emptyMap()

            Scaffold(
                snackbarHost = { SnackbarHost(snackbarHostState) },
                topBar = {
                    val title = topBarTitle(head, body)
                    val menu = body?.header?.menu
                    if (title != null || menu != null) {
                        TopAppBar(
                            title = { Text(title ?: "") },
                            actions = {
                                menu?.let { component ->
                                    ComponentView(
                                        component,
                                        headStyles = headStyles,
                                        stateManager = viewModel.stateManager,
                                        onHref = { viewModel.handleHref(it) },
                                        onAction = { viewModel.handleAction(it) }
                                    )
                                }
                            }
                        )
                    }
                },
                bottomBar = {
                    body?.footer?.let { footer ->
                        FooterView(
                            footer = footer,
                            headStyles = headStyles,
                            stateManager = viewModel.stateManager,
                            onHref = { viewModel.handleHref(it) },
                            onAction = { viewModel.handleAction(it) }
                        )
                    }
                }
            ) { padding ->
                val backgroundColor = bodyBackgroundCss(body)?.let { parseCssColor(it) }
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .let { modifier -> backgroundColor?.let { modifier.background(it) } ?: modifier }
                        .padding(padding),
                    verticalArrangement = Arrangement.spacedBy(0.dp)
                ) {
                    // Sections
                    body?.sections?.forEach { section ->
                        section.header?.let { header ->
                            item {
                                ComponentView(
                                    header,
                                    headStyles = headStyles,
                                    stateManager = viewModel.stateManager,
                                    onHref = { viewModel.handleHref(it) },
                                    onAction = { viewModel.handleAction(it) }
                                )
                            }
                        }
                        items(section.items ?: emptyList()) { component ->
                            ComponentView(
                                component,
                                headStyles = headStyles,
                                stateManager = viewModel.stateManager,
                                onHref = { viewModel.handleHref(it) },
                                onAction = { viewModel.handleAction(it) }
                            )
                        }
                    }

                    // Layers
                    body?.layers?.let { layers ->
                        items(layers) { component ->
                            ComponentView(
                                component,
                                headStyles = headStyles,
                                stateManager = viewModel.stateManager,
                                onHref = { viewModel.handleHref(it) },
                                onAction = { viewModel.handleAction(it) }
                            )
                        }
                    }
                }
            }
        }
    }

    alertMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { alertMessage = null },
            confirmButton = {
                TextButton(onClick = { alertMessage = null }) {
                    Text("OK")
                }
            },
            title = { Text(message.title ?: "Alert") },
            text = { Text(message.description ?: message.text ?: "") }
        )
    }

    (nativeUiRequest as? NativeUiRequest.Picker)?.let { picker ->
        AlertDialog(
            onDismissRequest = { viewModel.cancelNativeUiRequest() },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { viewModel.cancelNativeUiRequest() }) {
                    Text("CANCEL")
                }
            },
            title = { Text(picker.request.title ?: "Select") },
            text = {
                Column {
                    picker.request.items.forEach { item ->
                        TextButton(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = { viewModel.selectPickerItem(item.index) }
                        ) {
                            Text(item.text.ifBlank { " " })
                        }
                    }
                }
            }
        )
    }

    LaunchedEffect(nativeUiRequest) {
        val request = nativeUiRequest as? NativeUiRequest.MediaCapture ?: return@LaunchedEffect
        val route = request.request.source to request.request.mediaType
        val alreadyPending = when (route) {
            "camera" to "video" -> pendingVideoRequestId == request.id
            "camera" to "image" -> pendingPhotoRequestId == request.id
            "picker" to "video" -> pendingVideoPickerRequestId == request.id
            else -> pendingImagePickerRequestId == request.id
        }
        if (alreadyPending) return@LaunchedEffect
        runCatching {
            when (route) {
                "camera" to "video" -> {
                    pendingVideoRequestId = request.id
                    videoCaptureLauncher.launch(Uri.parse(requireNotNull(request.outputUri)))
                }
                "camera" to "image" -> {
                    pendingPhotoRequestId = request.id
                    photoCaptureLauncher.launch(Uri.parse(requireNotNull(request.outputUri)))
                }
                "picker" to "video" -> {
                    pendingVideoPickerRequestId = request.id
                    videoPickerLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly))
                }
                else -> {
                    pendingImagePickerRequestId = request.id
                    imagePickerLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }
            }
        }.onFailure {
            if (pendingPhotoRequestId == request.id) pendingPhotoRequestId = null
            if (pendingVideoRequestId == request.id) pendingVideoRequestId = null
            if (pendingImagePickerRequestId == request.id) pendingImagePickerRequestId = null
            if (pendingVideoPickerRequestId == request.id) pendingVideoPickerRequestId = null
            viewModel.cancelNativeUiRequest(request)
        }
    }

    DisposableEffect(nativeUiRequest, context) {
        val request = nativeUiRequest as? NativeUiRequest.VisionScan
        if (request == null) return@DisposableEffect onDispose { }
        startAndroidVisionScan(
            context = context,
            request = request.request,
            onResult = { payload -> viewModel.completeVisionScan(request, payload) },
            onCancel = { viewModel.cancelNativeUiRequest(request) }
        )
        onDispose { viewModel.cancelNativeUiRequest(request) }
    }

    DisposableEffect(nativeUiRequest, context) {
        val request = nativeUiRequest as? NativeUiRequest.DatePicker
        if (request == null) return@DisposableEffect onDispose { }
        val initial = Calendar.getInstance().apply {
            request.request.initialValue?.let { timeInMillis = it * 1000L }
        }
        var activeTimeDialog: TimePickerDialog? = null
        val dateDialog = DatePickerDialog(
            context,
            { _, year, month, day ->
                activeTimeDialog = TimePickerDialog(
                    context,
                    { _, hour, minute ->
                        val selected = Calendar.getInstance().apply {
                            set(year, month, day, hour, minute, 0)
                            set(Calendar.MILLISECOND, 0)
                        }
                        viewModel.completeDatePicker(selected.timeInMillis / 1000L)
                    },
                    initial.get(Calendar.HOUR_OF_DAY),
                    initial.get(Calendar.MINUTE),
                    true
                ).apply {
                    setTitle("Select Time")
                    setOnCancelListener { viewModel.cancelNativeUiRequest() }
                    show()
                }
            },
            initial.get(Calendar.YEAR),
            initial.get(Calendar.MONTH),
            initial.get(Calendar.DAY_OF_MONTH)
        ).apply {
            setTitle("Select Date")
            setOnCancelListener { viewModel.cancelNativeUiRequest() }
            show()
        }
        onDispose {
            dateDialog.dismiss()
            activeTimeDialog?.dismiss()
        }
    }

    LaunchedEffect(viewModel, snackbarHostState) {
        viewModel.utilityMessages.collect { message ->
            when (message.kind) {
                "alert" -> alertMessage = message
                "toast", "banner" -> {
                    val display = listOfNotNull(message.title, message.description, message.text)
                        .joinToString("\n")
                        .ifBlank { message.kind }
                    snackbarHostState.showSnackbar(display)
                }
            }
        }
    }

    LaunchedEffect(viewModel) { viewModel.loadIfNeeded() }
}

fun topBarTitle(head: JasonHead?, body: JasonBody?): String? =
    body?.header?.title ?: head?.title

fun bodyBackgroundCss(body: JasonBody?): String? =
    (body?.style?.get("background") as? JsonPrimitive)?.content
        ?: (body?.background as? JsonPrimitive)?.content

@Composable
private fun FooterView(
    footer: JasonFooter,
    headStyles: Map<String, JasonStyle>,
    stateManager: StateManager,
    onHref: ((JasonHref) -> Unit),
    onAction: ((JasonAction) -> Unit)
) {
    val tabs = footer.tabs?.items
    val input = footer.input
    Surface(tonalElevation = 3.dp) {
        when {
            tabs != null -> {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(8.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    tabs.forEach { item ->
                        ComponentView(
                            footerTabComponent(item),
                            headStyles = headStyles,
                            stateManager = stateManager,
                            onHref = onHref,
                            onAction = onAction
                        )
                    }
                }
            }
            input != null -> {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    input.left?.let { component ->
                        ComponentView(component, headStyles, stateManager, onHref, onAction)
                    }
                    ComponentView(
                        JasonComponent(
                            type = "textfield",
                            name = input.name,
                            placeholder = input.placeholder
                        ),
                        headStyles = headStyles,
                        stateManager = stateManager,
                        onHref = onHref,
                        onAction = onAction
                    )
                    input.right?.let { component ->
                        ComponentView(component, headStyles, stateManager, onHref, onAction)
                    }
                }
            }
        }
    }
}

fun footerTabComponent(item: JasonComponent): JasonComponent {
    if (item.href != null || item.url == null) return item
    val displayUrl = if (item.image == null && item.type == null && item.text != null) null else item.url
    return item.copy(url = displayUrl, href = JasonHref(url = item.url))
}

/** Convenience overload that creates a ViewModel from a URL. */
@Composable
fun JasonetteScreen(
    url: String,
    viewModelKey: String = url,
    onNavigate: ((JasonHref) -> Unit)? = null,
    onBack: (() -> Unit)? = null,
    onClose: (() -> Unit)? = null
) {
    val application = LocalContext.current.applicationContext as Application
    val viewModel: JasonetteViewModel = viewModel(
        key = viewModelKey,
        factory = object : ViewModelProvider.Factory {
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                @Suppress("UNCHECKED_CAST")
                return JasonetteViewModel(application, url = url) as T
            }
        }
    )
    JasonetteScreen(viewModel = viewModel, onNavigate = onNavigate, onBack = onBack, onClose = onClose)
}
