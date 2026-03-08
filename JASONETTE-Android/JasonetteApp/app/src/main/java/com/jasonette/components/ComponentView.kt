package com.jasonette.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.jasonette.core.*
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.floatOrNull

/**
 * Registry that dispatches Jasonette component types to Compose views.
 */
@Composable
fun ComponentView(
    component: JasonComponent,
    headStyles: Map<String, JasonStyle> = emptyMap(),
    stateManager: StateManager? = null,
    onHref: ((JasonHref) -> Unit)? = null,
    onAction: ((JasonAction) -> Unit)? = null
) {
    val modifier = buildStyleModifier(component.style, headStyles, component.className)
        .let { m ->
            val href = component.href
            val action = component.action
            when {
                href != null && onHref != null -> m.clickable { onHref(href) }
                action != null && onAction != null -> m.clickable { onAction(action) }
                else -> m
            }
        }

    Box(modifier = modifier) {
        when (component.type) {
            "label" -> LabelComponent(text = component.text ?: "")
            "image" -> ImageComponent(url = component.url, style = component.style)
            "button" -> ButtonComponent(text = component.text, url = component.url)
            "textfield" -> {
                val name = component.name ?: ""
                TextFieldComponent(
                    name = name,
                    placeholder = component.placeholder ?: "",
                    keyboard = component.keyboard,
                    value = stateManager?.local?.get(name) as? String ?: "",
                    onValueChange = { stateManager?.set(mapOf(name to it)) }
                )
            }
            "textarea" -> {
                val name = component.name ?: ""
                TextAreaComponent(
                    name = name,
                    placeholder = component.placeholder ?: "",
                    value = stateManager?.local?.get(name) as? String ?: "",
                    onValueChange = { stateManager?.set(mapOf(name to it)) }
                )
            }
            "slider" -> {
                val name = component.name ?: ""
                SliderComponent(
                    name = name,
                    value = (component.value as? JsonPrimitive)?.floatOrNull ?: 50f,
                    onValueChange = { stateManager?.set(mapOf(name to it)) }
                )
            }
            "space" -> SpaceComponent(height = component.style?.height?.dp)
            "switch" -> {
                val name = component.name ?: ""
                SwitchComponent(
                    name = name,
                    isOn = (component.value as? JsonPrimitive)?.content == "true",
                    onCheckedChange = { stateManager?.set(mapOf(name to it)) }
                )
            }
            "map" -> MapStubComponent()
            "vertical" -> LayoutView(
                direction = LayoutDirection.VERTICAL,
                components = component.components ?: emptyList(),
                headStyles = headStyles,
                style = component.style,
                stateManager = stateManager,
                onHref = onHref,
                onAction = onAction
            )
            "horizontal" -> LayoutView(
                direction = LayoutDirection.HORIZONTAL,
                components = component.components ?: emptyList(),
                headStyles = headStyles,
                style = component.style,
                stateManager = stateManager,
                onHref = onHref,
                onAction = onAction
            )
            else -> androidx.compose.material3.Text(
                text = "[Unknown: ${component.type ?: "nil"}]",
                color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

enum class LayoutDirection { VERTICAL, HORIZONTAL }

@Composable
fun LayoutView(
    direction: LayoutDirection,
    components: List<JasonComponent>,
    headStyles: Map<String, JasonStyle>,
    style: JasonStyle?,
    stateManager: StateManager?,
    onHref: ((JasonHref) -> Unit)?,
    onAction: ((JasonAction) -> Unit)?
) {
    val spacing = (style?.spacing?.dp ?: 8f).dp

    when (direction) {
        LayoutDirection.VERTICAL -> {
            Column(
                verticalArrangement = Arrangement.spacedBy(spacing),
                horizontalAlignment = when (style?.align) {
                    "center" -> Alignment.CenterHorizontally
                    "right" -> Alignment.End
                    else -> Alignment.Start
                }
            ) {
                components.forEach { comp ->
                    ComponentView(comp, headStyles, stateManager, onHref, onAction)
                }
            }
        }
        LayoutDirection.HORIZONTAL -> {
            Row(
                horizontalArrangement = Arrangement.spacedBy(spacing),
                verticalAlignment = when (style?.align) {
                    "center" -> Alignment.CenterVertically
                    "bottom" -> Alignment.Bottom
                    else -> Alignment.Top
                }
            ) {
                components.forEach { comp ->
                    ComponentView(comp, headStyles, stateManager, onHref, onAction)
                }
            }
        }
    }
}
