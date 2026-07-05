package com.jasonette.core

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
data class JasonDocument(
    @SerialName("\$jason") val jason: JasonRoot
)

@Serializable
data class JasonRoot(
    val head: JasonHead? = null,
    val body: JasonBody? = null
)

@Serializable
data class JasonHead(
    val title: String? = null,
    val data: JsonObject? = null,
    val templates: JsonObject? = null,
    val styles: Map<String, JasonStyle>? = null,
    val actions: Map<String, JasonAction>? = null
)

@Serializable
data class JasonBody(
    val background: JsonElement? = null,
    val header: JasonHeader? = null,
    val sections: List<JasonSection>? = null,
    val layers: List<JasonComponent>? = null,
    val footer: JasonFooter? = null
)

@Serializable
data class JasonHeader(
    val title: String? = null,
    val menu: JasonComponent? = null,
    val style: JasonStyle? = null
)

@Serializable
data class JasonSection(
    val header: JasonComponent? = null,
    val items: List<JasonComponent>? = null,
    val style: JasonStyle? = null
)

@Serializable
data class JasonComponent(
    val type: String? = null,
    val text: String? = null,
    val url: String? = null,
    val name: String? = null,
    val value: JsonElement? = null,
    val placeholder: String? = null,
    @SerialName("class") val className: String? = null,
    val style: JasonStyle? = null,
    val components: List<JasonComponent>? = null,
    val href: JasonHref? = null,
    val action: JasonAction? = null,
    val keyboard: String? = null,
    val image: String? = null
)

@Serializable
data class JasonHref(
    val url: String? = null,
    val view: String? = null,
    val transition: String? = null,
    val fresh: Boolean? = null,
    val preload: JsonElement? = null
)

@Serializable
data class JasonAction(
    val type: String? = null,
    val trigger: String? = null,
    val options: JsonObject? = null,
    val success: JasonAction? = null,
    val error: JasonAction? = null
)

@Serializable
data class JasonFooter(
    val tabs: JasonTabs? = null,
    val input: JasonFooterInput? = null
)

@Serializable
data class JasonFooterInput(
    val name: String? = null,
    val placeholder: String? = null,
    val left: JasonComponent? = null,
    val right: JasonComponent? = null
)

@Serializable
data class JasonTabs(
    val items: List<JasonComponent>? = null,
    val style: JasonStyle? = null
)

@Serializable
data class JasonStyle(
    val font: String? = null,
    val size: JsonPrimitive? = null,
    val color: String? = null,
    val background: String? = null,
    val padding: JsonPrimitive? = null,
    @SerialName("padding_left") val paddingLeft: JsonPrimitive? = null,
    @SerialName("padding_right") val paddingRight: JsonPrimitive? = null,
    @SerialName("padding_top") val paddingTop: JsonPrimitive? = null,
    @SerialName("padding_bottom") val paddingBottom: JsonPrimitive? = null,
    val width: JsonPrimitive? = null,
    val height: JsonPrimitive? = null,
    @SerialName("corner_radius") val cornerRadius: JsonPrimitive? = null,
    @SerialName("border_width") val borderWidth: JsonPrimitive? = null,
    @SerialName("border_color") val borderColor: String? = null,
    val align: String? = null,
    val spacing: JsonPrimitive? = null
) {
    fun mergeWith(other: JasonStyle): JasonStyle = JasonStyle(
        font = other.font ?: font,
        size = other.size ?: size,
        color = other.color ?: color,
        background = other.background ?: background,
        padding = other.padding ?: padding,
        paddingLeft = other.paddingLeft ?: paddingLeft,
        paddingRight = other.paddingRight ?: paddingRight,
        paddingTop = other.paddingTop ?: paddingTop,
        paddingBottom = other.paddingBottom ?: paddingBottom,
        width = other.width ?: width,
        height = other.height ?: height,
        cornerRadius = other.cornerRadius ?: cornerRadius,
        borderWidth = other.borderWidth ?: borderWidth,
        borderColor = other.borderColor ?: borderColor,
        align = other.align ?: align,
        spacing = other.spacing ?: spacing
    )
}

// Extension to extract float from JsonPrimitive
val JsonPrimitive?.dp: Float?
    get() = this?.floatOrNull
