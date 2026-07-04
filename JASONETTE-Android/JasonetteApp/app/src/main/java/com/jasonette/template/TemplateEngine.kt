package com.jasonette.template

/**
 * Jasonette template engine — transforms JSON templates with data.
 * Handles {{expr}}, {{#each items}}, {{#if cond}}.
 */
object TemplateEngine {
    private val exprPattern = Regex("""\{\{([^}]+(?:\}[^}]+)*)\}\}""")

    /** Render a template (Any JSON value) with a context. */
    fun render(template: Any?, context: Map<String, Any?>): Any? {
        return when (template) {
            is String -> interpolateString(template, context)
            is List<*> -> renderArray(template, context)
            is Map<*, *> -> renderObject(template, context)
            else -> template
        }
    }

    // String interpolation
    private fun interpolateString(str: String, context: Map<String, Any?>): Any? {
        val matches = exprPattern.findAll(str).toList()
        if (matches.isEmpty()) return str

        // Single expression covering entire string — return typed value
        if (matches.size == 1 && matches[0].range == str.indices) {
            val expr = matches[0].groupValues[1]
            return ExpressionEvaluator.evaluate(expr, context) ?: ""
        }

        // Multiple expressions — concatenate as string
        var result = str
        for (match in matches.reversed()) {
            val expr = match.groupValues[1]
            val value = ExpressionEvaluator.evaluate(expr, context)
            result = result.replaceRange(match.range, value?.toString() ?: "")
        }
        return result
    }

    // Array rendering
    private fun renderArray(arr: List<*>, context: Map<String, Any?>): List<Any?> {
        val result = mutableListOf<Any?>()
        for (item in arr) {
            if (item is Map<*, *>) {
                val directive = findDirective(item)
                if (directive != null) {
                    val rendered = applyDirective(directive, item, context)
                    if (rendered is List<*>) {
                        result.addAll(rendered)
                    } else {
                        result.add(rendered)
                    }
                    continue
                }
            }
            result.add(render(item, context))
        }
        return result
    }

    // Object rendering
    private fun renderObject(dict: Map<*, *>, context: Map<String, Any?>): Any? {
        val directive = findDirective(dict)
        if (directive != null) {
            return applyDirective(directive, dict, context)
        }

        val result = mutableMapOf<String, Any?>()
        for ((key, value) in dict) {
            val renderedKey = if (key is String) {
                val rendered = interpolateString(key, context)
                rendered?.toString() ?: key
            } else key.toString()
            result[renderedKey] = render(value, context)
        }
        return result
    }

    // Directives
    private sealed class Directive {
        data class Each(val expr: String, val template: Any?) : Directive()
        data class If(val expr: String, val template: Any?, val elseTemplate: Any?) : Directive()
    }

    private fun findDirective(dict: Map<*, *>): Directive? {
        for (key in dict.keys) {
            val k = key.toString()
            if (k.startsWith("{{#each ") && k.endsWith("}}")) {
                val expr = k.substring(8, k.length - 2)
                return Directive.Each(expr, dict[key])
            }
            if (k.startsWith("{{#if ") && k.endsWith("}}")) {
                val expr = k.substring(6, k.length - 2)
                val elseTemplate = dict["{{#else}}"]
                return Directive.If(expr, dict[key], elseTemplate)
            }
        }
        return null
    }

    private fun applyDirective(directive: Directive, dict: Map<*, *>, context: Map<String, Any?>): Any? {
        return when (directive) {
            is Directive.Each -> {
                val value = ExpressionEvaluator.evaluate(directive.expr, context)
                val items = value as? List<*> ?: return emptyList<Any>()

                items.mapIndexed { index, item ->
                    val itemContext = context.toMutableMap()
                    if (item is Map<*, *>) {
                        item.entries.forEach { (key, value) ->
                            key?.toString()?.let { itemContext[it] = value }
                        }
                    }
                    itemContext["\$jason"] = item
                    itemContext["\$index"] = index
                    context["\$jason"]?.let { itemContext["\$root"] = it }
                    render(directive.template, itemContext)
                }
            }
            is Directive.If -> {
                val condResult = ExpressionEvaluator.evaluate(directive.expr, context)
                if (ExpressionEvaluator.isTruthy(condResult)) {
                    render(directive.template, context)
                } else if (directive.elseTemplate != null) {
                    render(directive.elseTemplate, context)
                } else {
                    emptyList<Any>()
                }
            }
        }
    }
}
