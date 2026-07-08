package com.jasonette.template

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.round
import java.util.Date

/**
 * Evaluates expression ASTs against a context map.
 * Includes security layers: function allowlist, property blocklist, depth limit.
 */
object ExpressionEvaluator {

    private val blockedProperties = setOf("__proto__", "constructor", "prototype")

    private val safeFunctions: Map<String, (List<Any?>) -> Any?> = mapOf(
        "Math.floor" to { args -> args.firstOrNull()?.toDoubleOrNull()?.let { floor(it).toInt() } },
        "Math.ceil" to { args -> args.firstOrNull()?.toDoubleOrNull()?.let { ceil(it).toInt() } },
        "Math.round" to { args -> args.firstOrNull()?.toDoubleOrNull()?.let { round(it).toInt() } },
        "Math.abs" to { args -> args.firstOrNull()?.toDoubleOrNull()?.let { abs(it) } },
        "Math.min" to { args -> args.mapNotNull { it?.toDoubleOrNull() }.minOrNull() },
        "Math.max" to { args -> args.mapNotNull { it?.toDoubleOrNull() }.maxOrNull() },
        "parseInt" to { args -> args.firstOrNull()?.toDoubleOrNull()?.toInt() },
        "parseFloat" to { args -> args.firstOrNull()?.toDoubleOrNull() },
        "String" to { args -> args.firstOrNull()?.toString() },
        "Number" to { args -> args.firstOrNull()?.toDoubleOrNull() },
        "Array.isArray" to { args -> args.firstOrNull() is List<*> },
    )

    /** Evaluate an expression string against a context. */
    fun evaluate(expression: String, context: Map<String, Any?>): Any? {
        val trimmed = expression.trim()
        if (trimmed.isEmpty()) return null
        legacyDateToString(trimmed, context)?.let { return it }
        return try {
            val node = ExpressionParser(trimmed).parse()
            resolve(node, context)
        } catch (_: Exception) {
            null
        }
    }

    private fun legacyDateToString(expression: String, context: Map<String, Any?>): String? {
        val inner = Regex("^\\(new\\s+Date\\((.*)\\)\\)\\.toString\\(\\)$").matchEntire(expression)
            ?.groupValues
            ?.getOrNull(1)
            ?: return null
        val millis = legacyDateMillis(inner, context) ?: return null
        return Date(millis).toString()
    }

    private fun legacyDateMillis(expression: String, context: Map<String, Any?>): Long? {
        val parseIntTimes = Regex("^parseInt\\((.*)\\)\\s*\\*\\s*1000$").matchEntire(expression.trim())
        if (parseIntTimes != null) {
            val seconds = evaluate(parseIntTimes.groupValues[1], context)?.toString()?.toLongOrNull() ?: return null
            return seconds * 1000L
        }
        return evaluate(expression, context)?.toDoubleOrNull()?.toLong()
    }

    fun resolve(node: Node, context: Map<String, Any?>, depth: Int = 0): Any? {
        if (depth > 20) return null

        return when (node) {
            is Node.Literal -> node.value

            is Node.Identifier -> context[node.name]

            is Node.Member -> {
                if (node.property in blockedProperties) return null
                if (node.obj is Node.Identifier) {
                    val fullName = "${node.obj.name}.${node.property}"
                    if (fullName in safeFunctions) return fullName
                }
                val obj = resolve(node.obj, context, depth + 1) ?: return null
                accessProperty(obj, node.property)
            }

            is Node.ComputedMember -> {
                val obj = resolve(node.obj, context, depth + 1) ?: return null
                val key = resolve(node.property, context, depth + 1) ?: return null
                when {
                    obj is List<*> && key is Int -> obj.getOrNull(key)
                    obj is Map<*, *> && key is String -> obj[key]
                    else -> null
                }
            }

            is Node.Binary -> evaluateBinary(node.op, node.left, node.right, context, depth)

            is Node.Unary -> {
                val value = resolve(node.operand, context, depth + 1)
                when (node.op) {
                    "!" -> !isTruthy(value)
                    "-" -> value?.toDoubleOrNull()?.let { -it }
                    "+" -> value?.toDoubleOrNull()
                    "typeof" -> typeofValue(value)
                    else -> null
                }
            }

            is Node.Ternary -> {
                val cond = resolve(node.condition, context, depth + 1)
                if (isTruthy(cond)) resolve(node.consequent, context, depth + 1)
                else resolve(node.alternate, context, depth + 1)
            }

            is Node.Call -> {
                val args = node.args.map { resolve(it, context, depth + 1) }
                val ref = resolve(node.callee, context, depth + 1)
                if (ref is String && ref in safeFunctions) {
                    safeFunctions[ref]?.invoke(args)
                } else if (node.callee is Node.Identifier) {
                    safeFunctions[node.callee.name]?.invoke(args)
                } else null
            }

            is Node.ArrayLiteral -> node.elements.map { resolve(it, context, depth + 1) }
        }
    }

    fun isTruthy(value: Any?): Boolean {
        if (value == null) return false
        return when (value) {
            is Boolean -> value
            is Int -> value != 0
            is Double -> value != 0.0
            is String -> value.isNotEmpty()
            is List<*> -> value.isNotEmpty()
            else -> true
        }
    }

    private fun evaluateBinary(
        op: String, left: Node, right: Node,
        context: Map<String, Any?>, depth: Int
    ): Any? {
        // Short-circuit
        if (op == "&&") {
            val l = resolve(left, context, depth + 1)
            return if (isTruthy(l)) resolve(right, context, depth + 1) else l
        }
        if (op == "||") {
            val l = resolve(left, context, depth + 1)
            return if (isTruthy(l)) l else resolve(right, context, depth + 1)
        }

        val l = resolve(left, context, depth + 1)
        val r = resolve(right, context, depth + 1)

        return when (op) {
            "+" -> {
                if (l is String) l + (r?.toString() ?: "")
                else if (r is String) (l?.toString() ?: "") + r
                else if (l is Int && r is Int) l + r
                else {
                    val ld = l?.toDoubleOrNull()
                    val rd = r?.toDoubleOrNull()
                    if (ld != null && rd != null) ld + rd else null
                }
            }
            "-" -> intOrDouble(l, r, Int::minus, Double::minus)
            "*" -> intOrDouble(l, r, Int::times, Double::times)
            "/" -> {
                val rd = r?.toDoubleOrNull() ?: return null
                if (rd == 0.0) return null
                val li = l as? Int; val ri = r as? Int
                if (li != null && ri != null && li % ri == 0) li / ri
                else l?.toDoubleOrNull()?.let { it / rd }
            }
            "%" -> {
                val li = l as? Int; val ri = r as? Int
                if (li != null && ri != null && ri != 0) li % ri
                else {
                    val rd = r?.toDoubleOrNull() ?: return null
                    if (rd == 0.0) null else l?.toDoubleOrNull()?.rem(rd)
                }
            }
            "==", "===" -> looseEqual(l, r)
            "!=", "!==" -> !looseEqual(l, r)
            "<" -> compareValues(l, r)?.let { it < 0 }
            "<=" -> compareValues(l, r)?.let { it <= 0 }
            ">" -> compareValues(l, r)?.let { it > 0 }
            ">=" -> compareValues(l, r)?.let { it >= 0 }
            "in" -> {
                val key = l as? String ?: return false
                val obj = r as? Map<*, *> ?: return false
                key in obj
            }
            else -> null
        }
    }

    private fun intOrDouble(
        l: Any?, r: Any?,
        intOp: (Int, Int) -> Int,
        doubleOp: (Double, Double) -> Double
    ): Any? {
        val li = l as? Int; val ri = r as? Int
        if (li != null && ri != null) return intOp(li, ri)
        val ld = l?.toDoubleOrNull(); val rd = r?.toDoubleOrNull()
        return if (ld != null && rd != null) doubleOp(ld, rd) else null
    }

    private fun accessProperty(obj: Any, key: String): Any? {
        if (obj is Map<*, *>) return obj[key]
        if (key == "length") {
            if (obj is List<*>) return obj.size
            if (obj is String) return obj.length
        }
        return null
    }

    private fun looseEqual(l: Any?, r: Any?): Boolean {
        if (l == null && r == null) return true
        if (l is String && r is String) return l == r
        if (l is Boolean && r is Boolean) return l == r
        val ld = l?.toDoubleOrNull(); val rd = r?.toDoubleOrNull()
        if (ld != null && rd != null) return ld == rd
        return false
    }

    private fun compareValues(l: Any?, r: Any?): Int? {
        val ld = l?.toDoubleOrNull(); val rd = r?.toDoubleOrNull()
        if (ld != null && rd != null) return ld.compareTo(rd)
        if (l is String && r is String) return l.compareTo(r)
        return null
    }

    private fun typeofValue(v: Any?): String = when (v) {
        null -> "undefined"
        is Boolean -> "boolean"
        is Int, is Double -> "number"
        is String -> "string"
        is List<*>, is Map<*, *> -> "object"
        else -> "undefined"
    }
}

/** Extension to convert Any? to Double. */
fun Any?.toDoubleOrNull(): Double? = when (this) {
    is Double -> this
    is Int -> this.toDouble()
    is Float -> this.toDouble()
    is Long -> this.toDouble()
    is String -> try { this.toDouble() } catch (_: NumberFormatException) { null }
    else -> null
}
