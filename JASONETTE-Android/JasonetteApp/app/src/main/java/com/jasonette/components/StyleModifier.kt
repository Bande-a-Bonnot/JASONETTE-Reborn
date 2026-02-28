package com.jasonette.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.jasonette.core.JasonStyle
import com.jasonette.core.dp

/**
 * Builds a Compose Modifier from Jasonette style properties.
 */
fun buildStyleModifier(
    inlineStyle: JasonStyle?,
    headStyles: Map<String, JasonStyle>,
    className: String?
): Modifier {
    val style = resolveStyle(inlineStyle, headStyles, className) ?: return Modifier

    var modifier = Modifier as Modifier

    // Padding
    style.padding?.dp?.let { modifier = modifier.padding(it.dp) }

    // Background
    style.background?.let { hex ->
        parseHexColor(hex)?.let { modifier = modifier.background(it) }
    }

    // Corner radius
    style.cornerRadius?.dp?.let {
        modifier = modifier.clip(RoundedCornerShape(it.dp))
    }

    return modifier
}

private fun resolveStyle(
    inline: JasonStyle?,
    headStyles: Map<String, JasonStyle>,
    className: String?
): JasonStyle? {
    val base = className?.let { headStyles[it] }
    return when {
        base != null && inline != null -> base.mergeWith(inline)
        inline != null -> inline
        base != null -> base
        else -> null
    }
}

fun parseHexColor(hex: String): Color? {
    val h = hex.trimStart('#')
    return try {
        when (h.length) {
            6 -> Color(android.graphics.Color.parseColor("#$h"))
            8 -> Color(android.graphics.Color.parseColor("#$h"))
            else -> null
        }
    } catch (_: Exception) {
        null
    }
}
