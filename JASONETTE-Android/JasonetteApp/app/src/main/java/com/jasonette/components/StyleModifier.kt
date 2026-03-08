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

    var modifier: Modifier = Modifier

    // Padding
    style.padding?.dp?.let { modifier = modifier.padding(it.dp) }

    // Background
    style.background?.let { css ->
        parseCssColor(css)?.let { modifier = modifier.background(it) }
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
    // Support multi-class: "bold padded" → merge "bold" then "padded"
    val base = className?.split(" ")
        ?.mapNotNull { headStyles[it.trim()] }
        ?.reduceOrNull { acc, style -> acc.mergeWith(style) }
    return when {
        base != null && inline != null -> base.mergeWith(inline)
        inline != null -> inline
        base != null -> base
        else -> null
    }
}

/** Unified CSS color parser: hex, rgb(), rgba(). */
fun parseCssColor(css: String): Color? {
    val s = css.trim().lowercase()
    return when {
        s.startsWith("#") -> parseHexColor(s)
        s.startsWith("rgb") -> parseRgbColor(s)
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

/** Parses rgb(r,g,b) and rgba(r,g,b,a) — manual string splitting, no regex. */
fun parseRgbColor(css: String): Color? {
    val s = css.trim().lowercase()
    val isRgba = s.startsWith("rgba(")
    val isRgb = s.startsWith("rgb(")
    if ((!isRgb && !isRgba) || !s.endsWith(")")) return null
    val prefix = if (isRgba) 5 else 4
    val inner = s.substring(prefix, s.length - 1)
    val parts = inner.split(",").map { it.trim() }
    if (isRgb && parts.size != 3) return null
    if (isRgba && parts.size != 4) return null
    val r = parts[0].toIntOrNull() ?: return null
    val g = parts[1].toIntOrNull() ?: return null
    val b = parts[2].toIntOrNull() ?: return null
    if (r !in 0..255 || g !in 0..255 || b !in 0..255) return null
    val a = if (parts.size == 4) {
        (parts[3].toFloatOrNull() ?: 1f).coerceIn(0f, 1f)
    } else 1f
    return Color(r / 255f, g / 255f, b / 255f, a)
}
