package com.jasonette.components

import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import coil.compose.AsyncImage
import com.jasonette.core.JasonComponent
import com.jasonette.core.JasonStyle
import com.jasonette.core.dp
import kotlinx.serialization.json.content

// Label
@Composable
fun LabelComponent(text: String) {
    Text(text = text)
}

// Image
@Composable
fun ImageComponent(url: String?, style: JasonStyle?) {
    if (url != null) {
        AsyncImage(
            model = url,
            contentDescription = null,
            modifier = Modifier
                .let { m ->
                    val w = style?.width?.dp
                    val h = style?.height?.dp
                    when {
                        w != null && h != null -> m.size(w.dp, h.dp)
                        w != null -> m.width(w.dp)
                        h != null -> m.height(h.dp)
                        else -> m
                    }
                }
        )
    }
}

// Button
@Composable
fun ButtonComponent(text: String?, url: String?) {
    if (url != null) {
        AsyncImage(model = url, contentDescription = text)
    } else {
        Text(text = text ?: "Button")
    }
}

// TextField (stateless — state hoisted via onValueChange)
@Composable
fun TextFieldComponent(
    name: String,
    placeholder: String,
    keyboard: String?,
    value: String,
    onValueChange: (String) -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder) },
        keyboardOptions = KeyboardOptions(
            keyboardType = when (keyboard) {
                "number", "numeric" -> KeyboardType.Number
                "decimal" -> KeyboardType.Decimal
                "phone" -> KeyboardType.Phone
                "email" -> KeyboardType.Email
                "url" -> KeyboardType.Uri
                else -> KeyboardType.Text
            }
        ),
        modifier = Modifier.fillMaxWidth()
    )
}

// TextArea (stateless — state hoisted via onValueChange)
@Composable
fun TextAreaComponent(
    name: String,
    placeholder: String,
    value: String,
    onValueChange: (String) -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder) },
        minLines = 3,
        modifier = Modifier.fillMaxWidth()
    )
}

// Slider (stateless — state hoisted via onValueChange)
@Composable
fun SliderComponent(
    name: String,
    value: Float,
    onValueChange: (Float) -> Unit
) {
    Slider(
        value = value,
        onValueChange = onValueChange,
        valueRange = 0f..100f
    )
}

// Space
@Composable
fun SpaceComponent(height: Float?) {
    Spacer(modifier = Modifier.height((height ?: 10f).dp))
}

// Switch (stateless — state hoisted via onCheckedChange)
@Composable
fun SwitchComponent(
    name: String,
    isOn: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Switch(checked = isOn, onCheckedChange = onCheckedChange)
}

@Composable
fun HtmlComponent(component: JasonComponent) {
    AndroidView(
        modifier = Modifier
            .fillMaxWidth()
            .height((component.style?.height?.dp ?: 240f).dp),
        factory = { context ->
            WebView(context).apply {
                settings.defaultTextEncodingName = "utf-8"
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.javaScriptCanOpenWindowsAutomatically = false
                settings.mediaPlaybackRequiresUserGesture = false
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.layoutAlgorithm = WebSettings.LayoutAlgorithm.TEXT_AUTOSIZING
                webChromeClient = WebChromeClient()
                isVerticalScrollBarEnabled = false
                isHorizontalScrollBarEnabled = false
            }
        },
        update = { webView ->
            val loadKey = htmlComponentLoadKey(component) ?: return@AndroidView
            if (webView.tag == loadKey) return@AndroidView
            webView.tag = loadKey

            val source = htmlComponentSource(component)
            if (source != null) {
                webView.loadDataWithBaseURL(
                    htmlComponentUrl(component) ?: "http://localhost/",
                    source,
                    "text/html",
                    "utf-8",
                    null
                )
            } else {
                htmlComponentUrl(component)?.let { webView.loadUrl(it) }
            }
        }
    )
}

fun htmlComponentSource(component: JasonComponent): String? =
    component.text?.let { text ->
        if (component.css.isNullOrBlank()) text else "<style>${component.css}</style>$text"
    }

fun htmlComponentUrl(component: JasonComponent): String? =
    component.url?.takeIf { it.startsWith("https://") || it.startsWith("http://") }

fun htmlComponentLoadKey(component: JasonComponent): String? =
    htmlComponentSource(component)?.let { "html:${htmlComponentUrl(component).orEmpty()}:$it" }
        ?: htmlComponentUrl(component)?.let { "url:$it" }

@Composable
fun MapComponent(component: JasonComponent) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height((component.style?.height?.dp ?: 200f).dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.medium
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.Center
        ) {
            Text("Map", style = MaterialTheme.typography.titleMedium)
            mapRegionLabel(component)?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            mapPinLabels(component).forEach { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

fun mapRegionLabel(component: JasonComponent): String? =
    component.region?.coord?.takeIf { it.isNotBlank() }?.let { coord ->
        val width = component.region.width?.content
        val height = component.region.height?.content
        when {
            width != null && height != null -> "Region $coord (${width}m x ${height}m)"
            else -> "Region $coord"
        }
    }

fun mapPinLabels(component: JasonComponent): List<String> =
    component.pins.orEmpty().mapIndexed { index, pin ->
        val label = pin.title ?: "Pin ${index + 1}"
        val description = pin.description?.let { " — $it" }.orEmpty()
        val coord = pin.coord?.let { " @ $it" }.orEmpty()
        "$label$description$coord"
    }

// Unsupported native component stubs
@Composable
fun UnsupportedStubComponent(label: String) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.medium
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
            Text("$label not supported yet", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
