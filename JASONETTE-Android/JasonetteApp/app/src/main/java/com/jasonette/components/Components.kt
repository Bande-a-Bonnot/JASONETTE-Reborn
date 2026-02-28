package com.jasonette.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.jasonette.core.JasonComponent
import com.jasonette.core.JasonStyle
import com.jasonette.core.dp

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

// TextField
@Composable
fun TextFieldComponent(name: String, placeholder: String, keyboard: String?) {
    var text by remember { mutableStateOf("") }
    OutlinedTextField(
        value = text,
        onValueChange = { text = it },
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

// TextArea
@Composable
fun TextAreaComponent(name: String, placeholder: String) {
    var text by remember { mutableStateOf("") }
    OutlinedTextField(
        value = text,
        onValueChange = { text = it },
        placeholder = { Text(placeholder) },
        minLines = 3,
        modifier = Modifier.fillMaxWidth()
    )
}

// Slider
@Composable
fun SliderComponent(name: String, value: Float) {
    var current by remember { mutableFloatStateOf(value) }
    Slider(
        value = current,
        onValueChange = { current = it },
        valueRange = 0f..100f
    )
}

// Space
@Composable
fun SpaceComponent(height: Float?) {
    Spacer(modifier = Modifier.height((height ?: 10f).dp))
}

// Switch
@Composable
fun SwitchComponent(name: String, isOn: Boolean) {
    var checked by remember { mutableStateOf(isOn) }
    Switch(checked = checked, onCheckedChange = { checked = it })
}

// Map stub
@Composable
fun MapStubComponent() {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.medium
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
            Text("Map", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
