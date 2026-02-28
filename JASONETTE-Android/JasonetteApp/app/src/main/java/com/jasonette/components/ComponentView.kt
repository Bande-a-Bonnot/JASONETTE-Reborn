package com.jasonette.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.jasonette.core.*

/**
 * Registry that dispatches Jasonette component types to Compose views.
 */
@Composable
fun ComponentView(
    component: JasonComponent,
    headStyles: Map<String, JasonStyle> = emptyMap(),
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
            "textfield" -> TextFieldComponent(
                name = component.name ?: "",
                placeholder = component.placeholder ?: "",
                keyboard = component.keyboard
            )
            "textarea" -> TextAreaComponent(
                name = component.name ?: "",
                placeholder = component.placeholder ?: ""
            )
            "slider" -> SliderComponent(
                name = component.name ?: "",
                value = component.value?.floatOrNull ?: 50f
            )
            "space" -> SpaceComponent(height = component.style?.height?.dp)
            "switch" -> SwitchComponent(
                name = component.name ?: "",
                isOn = component.value?.let {
                    it.content == "true"
                } ?: false
            )
            "map" -> MapStubComponent()
            "vertical" -> LayoutView(
                direction = LayoutDirection.VERTICAL,
                components = component.components ?: emptyList(),
                headStyles = headStyles,
                style = component.style,
                onHref = onHref,
                onAction = onAction
            )
            "horizontal" -> LayoutView(
                direction = LayoutDirection.HORIZONTAL,
                components = component.components ?: emptyList(),
                headStyles = headStyles,
                style = component.style,
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
    onHref: ((JasonHref) -> Unit)?,
    onAction: ((JasonAction) -> Unit)?
) {
    val spacing = style?.spacing?.dp?.dp ?: 8.dp

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
                    ComponentView(comp, headStyles, onHref, onAction)
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
                    ComponentView(comp, headStyles, onHref, onAction)
                }
            }
        }
    }
}
