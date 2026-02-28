package com.jasonette.template

/**
 * Recursive-descent parser for JS-like expressions.
 * Produces ExpressionEvaluator.Node AST.
 */
class ExpressionParser(private val input: String) {
    private var pos = 0

    fun parse(): Node {
        val result = parseTernary()
        skipWhitespace()
        return result
    }

    // Ternary: expr ? expr : expr
    private fun parseTernary(): Node {
        var result = parseOr()
        skipWhitespace()
        if (peek() == '?') {
            advance()
            val consequent = parseTernary()
            expect(':')
            val alternate = parseTernary()
            result = Node.Ternary(result, consequent, alternate)
        }
        return result
    }

    // Logical OR: expr || expr
    private fun parseOr(): Node {
        var left = parseAnd()
        while (matchStr("||")) {
            left = Node.Binary("||", left, parseAnd())
        }
        return left
    }

    // Logical AND: expr && expr
    private fun parseAnd(): Node {
        var left = parseEquality()
        while (matchStr("&&")) {
            left = Node.Binary("&&", left, parseEquality())
        }
        return left
    }

    // Equality: == != === !==
    private fun parseEquality(): Node {
        var left = parseComparison()
        while (true) {
            skipWhitespace()
            val op = when {
                matchStr("===") -> "==="
                matchStr("!==") -> "!=="
                matchStr("==") -> "=="
                matchStr("!=") -> "!="
                else -> break
            }
            left = Node.Binary(op, left, parseComparison())
        }
        return left
    }

    // Comparison: < <= > >= in
    private fun parseComparison(): Node {
        var left = parseAddition()
        while (true) {
            skipWhitespace()
            val op = when {
                matchStr("<=") -> "<="
                matchStr(">=") -> ">="
                matchStr("<") -> "<"
                matchStr(">") -> ">"
                matchWord("in") -> "in"
                else -> break
            }
            left = Node.Binary(op, left, parseAddition())
        }
        return left
    }

    // Addition: + -
    private fun parseAddition(): Node {
        var left = parseMultiplication()
        while (true) {
            skipWhitespace()
            val op = when {
                matchStr("+") -> "+"
                matchStr("-") && !isDigit(peek()) -> "-"
                else -> break
            }
            left = Node.Binary(op, left, parseMultiplication())
        }
        return left
    }

    // Multiplication: * / %
    private fun parseMultiplication(): Node {
        var left = parseUnary()
        while (true) {
            skipWhitespace()
            val op = when {
                matchStr("*") -> "*"
                matchStr("/") -> "/"
                matchStr("%") -> "%"
                else -> break
            }
            left = Node.Binary(op, left, parseUnary())
        }
        return left
    }

    // Unary: ! - + typeof
    private fun parseUnary(): Node {
        skipWhitespace()
        if (matchStr("!")) return Node.Unary("!", parseUnary())
        if (matchStr("-") && !isDigit(peekPrev())) return Node.Unary("-", parseUnary())
        if (matchStr("+") && !isDigit(peekPrev())) return Node.Unary("+", parseUnary())
        if (matchWord("typeof")) return Node.Unary("typeof", parseUnary())
        return parseCallMember()
    }

    // Call / member access
    private fun parseCallMember(): Node {
        var node = parsePrimary()
        while (true) {
            skipWhitespace()
            when {
                peek() == '.' -> {
                    advance()
                    val prop = readIdentifier()
                    node = Node.Member(node, prop)
                }
                peek() == '[' -> {
                    advance()
                    val expr = parseTernary()
                    expect(']')
                    node = Node.ComputedMember(node, expr)
                }
                peek() == '(' -> {
                    advance()
                    val args = mutableListOf<Node>()
                    skipWhitespace()
                    if (peek() != ')') {
                        args.add(parseTernary())
                        while (peek() == ',') {
                            advance()
                            args.add(parseTernary())
                        }
                    }
                    expect(')')
                    node = Node.Call(node, args)
                }
                else -> break
            }
        }
        return node
    }

    // Primary: number, string, bool, null, undefined, identifier, array, parenthesized
    private fun parsePrimary(): Node {
        skipWhitespace()

        // Number
        if (isDigit(peek()) || (peek() == '-' && isDigit(peekNext()))) {
            return parseNumber()
        }

        // String
        if (peek() == '\'' || peek() == '"') {
            return parseString()
        }

        // Array
        if (peek() == '[') {
            advance()
            val elements = mutableListOf<Node>()
            skipWhitespace()
            if (peek() != ']') {
                elements.add(parseTernary())
                while (peek() == ',') {
                    advance()
                    elements.add(parseTernary())
                }
            }
            expect(']')
            return Node.ArrayLiteral(elements)
        }

        // Parenthesized
        if (peek() == '(') {
            advance()
            val expr = parseTernary()
            expect(')')
            return expr
        }

        // Identifier or keyword
        val ident = readIdentifier()
        return when (ident) {
            "true" -> Node.Literal(true)
            "false" -> Node.Literal(false)
            "null", "undefined" -> Node.Literal(null)
            else -> Node.Identifier(ident)
        }
    }

    private fun parseNumber(): Node {
        val start = pos
        if (peek() == '-') advance()
        while (pos < input.length && isDigit(input[pos])) advance()
        if (pos < input.length && input[pos] == '.') {
            advance()
            while (pos < input.length && isDigit(input[pos])) advance()
            return Node.Literal(input.substring(start, pos).toDouble())
        }
        return Node.Literal(input.substring(start, pos).toInt())
    }

    private fun parseString(): Node {
        val quote = advance()
        val sb = StringBuilder()
        while (pos < input.length && input[pos] != quote) {
            if (input[pos] == '\\') {
                advance()
                sb.append(input[pos])
            } else {
                sb.append(input[pos])
            }
            advance()
        }
        if (pos < input.length) advance() // closing quote
        return Node.Literal(sb.toString())
    }

    private fun readIdentifier(): String {
        skipWhitespace()
        val start = pos
        while (pos < input.length && (input[pos].isLetterOrDigit() || input[pos] == '_' || input[pos] == '$')) {
            advance()
        }
        if (pos == start) throw ParseException("Expected identifier at position $pos")
        return input.substring(start, pos)
    }

    // Helpers
    private fun peek(): Char = if (pos < input.length) input[pos] else '\u0000'
    private fun peekNext(): Char = if (pos + 1 < input.length) input[pos + 1] else '\u0000'
    private fun peekPrev(): Char = if (pos > 0) input[pos - 1] else '\u0000'
    private fun advance(): Char { val c = input[pos]; pos++; return c }
    private fun skipWhitespace() { while (pos < input.length && input[pos].isWhitespace()) pos++ }
    private fun isDigit(c: Char) = c in '0'..'9'

    private fun expect(c: Char) {
        skipWhitespace()
        if (peek() != c) throw ParseException("Expected '$c' at position $pos")
        advance()
    }

    private fun matchStr(s: String): Boolean {
        skipWhitespace()
        if (input.startsWith(s, pos)) {
            // For multi-char operators, ensure no alphanumeric follows
            val endPos = pos + s.length
            if (s.length > 1 && s.all { it.isLetter() } && endPos < input.length && input[endPos].isLetterOrDigit()) {
                return false
            }
            pos += s.length
            return true
        }
        return false
    }

    private fun matchWord(word: String): Boolean {
        skipWhitespace()
        if (input.startsWith(word, pos)) {
            val endPos = pos + word.length
            if (endPos >= input.length || !input[endPos].isLetterOrDigit()) {
                pos = endPos
                return true
            }
        }
        return false
    }

    class ParseException(message: String) : Exception(message)
}
