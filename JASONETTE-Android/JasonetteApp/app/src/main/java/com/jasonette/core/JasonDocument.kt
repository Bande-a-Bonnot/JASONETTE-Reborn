package com.jasonette.core

import kotlinx.serialization.*
import kotlinx.serialization.descriptors.*
import kotlinx.serialization.encoding.*
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
    val style: JsonObject? = null,
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
    val css: String? = null,
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

@Serializable(with = JasonActionSerializer::class)
data class JasonAction(
    val type: String? = null,
    val trigger: String? = null,
    val options: JsonElement? = null,
    val success: JasonAction? = null,
    val error: JasonAction? = null,
    @Transient val successActions: List<JasonAction> = success?.let { listOf(it) } ?: emptyList(),
    @Transient val errorActions: List<JasonAction> = error?.let { listOf(it) } ?: emptyList(),
    @Transient val successElement: JsonElement? = null,
    @Transient val errorElement: JsonElement? = null
)

@OptIn(ExperimentalSerializationApi::class)
object JasonActionSerializer : KSerializer<JasonAction> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("JasonAction") {
        element<String>("type", isOptional = true)
        element<String>("trigger", isOptional = true)
        element<JsonElement>("options", isOptional = true)
        element<JsonElement>("success", isOptional = true)
        element<JsonElement>("error", isOptional = true)
    }

    override fun deserialize(decoder: Decoder): JasonAction {
        val jsonDecoder = decoder as? JsonDecoder
            ?: throw SerializationException("JasonAction can only be decoded from JSON")
        val element = jsonDecoder.decodeJsonElement()
        val obj = element as? JsonObject
            ?: throw SerializationException("JasonAction must be a JSON object")
        val successElement = obj["success"]
        val errorElement = obj["error"]
        val successActions = decodeActionList(jsonDecoder.json, successElement)
        val errorActions = decodeActionList(jsonDecoder.json, errorElement)
        return JasonAction(
            type = (obj["type"] as? JsonPrimitive)?.content,
            trigger = (obj["trigger"] as? JsonPrimitive)?.content,
            options = obj["options"],
            success = successActions.firstOrNull(),
            error = errorActions.firstOrNull(),
            successActions = successActions,
            errorActions = errorActions,
            successElement = successElement,
            errorElement = errorElement
        )
    }

    override fun serialize(encoder: Encoder, value: JasonAction) {
        val jsonEncoder = encoder as? JsonEncoder
            ?: throw SerializationException("JasonAction can only be encoded to JSON")
        val content = buildMap<String, JsonElement> {
            value.type?.let { put("type", JsonPrimitive(it)) }
            value.trigger?.let { put("trigger", JsonPrimitive(it)) }
            value.options?.let { put("options", it) }
            encodedContinuation(jsonEncoder.json, value.successElement, value.successActions, value.success)?.let { put("success", it) }
            encodedContinuation(jsonEncoder.json, value.errorElement, value.errorActions, value.error)?.let { put("error", it) }
        }
        jsonEncoder.encodeJsonElement(JsonObject(content))
    }

    private fun encodedContinuation(
        json: Json,
        raw: JsonElement?,
        actions: List<JasonAction>,
        single: JasonAction?
    ): JsonElement? = raw
        ?: when {
            actions.size > 1 -> JsonArray(actions.map { json.encodeToJsonElement(JasonAction.serializer(), it) })
            actions.size == 1 -> json.encodeToJsonElement(JasonAction.serializer(), actions.first())
            single != null -> json.encodeToJsonElement(JasonAction.serializer(), single)
            else -> null
        }

    private fun decodeActionList(json: Json, element: JsonElement?): List<JasonAction> = when (element) {
        null -> emptyList()
        is JsonArray -> element.mapNotNull { decodeActionOrNull(json, it) }
        is JsonObject -> decodeActionOrNull(json, element)?.let { listOf(it) } ?: emptyList()
        else -> emptyList()
    }

    private fun decodeActionOrNull(json: Json, element: JsonElement): JasonAction? =
        runCatching { json.decodeFromJsonElement(JasonAction.serializer(), element) }.getOrNull()
}

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
