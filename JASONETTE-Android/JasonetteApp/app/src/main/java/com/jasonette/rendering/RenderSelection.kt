package com.jasonette.rendering

/**
 * Tracks the active Android render template and payload without depending on
 * Android lifecycle types, so parity rules stay unit-testable on the JVM.
 */
internal class RenderSelection(
    private val defaultTemplateName: String = "body"
) {
    var templateName: String = defaultTemplateName
        private set

    var renderData: Any? = null
        private set

    var hasRenderData: Boolean = false
        private set

    fun apply(templateName: String?, renderData: Any?, hasRenderData: Boolean = renderData != null) {
        this.templateName = templateName ?: defaultTemplateName
        if (hasRenderData) {
            this.renderData = renderData
            this.hasRenderData = true
        }
    }

    fun reset() {
        templateName = defaultTemplateName
        renderData = null
        hasRenderData = false
    }
}
