import Foundation

/// Recursive-descent parser for JavaScript-like expressions.
/// Produces an AST that ExpressionEvaluator can resolve.
final class ExpressionParser {
    private let chars: [Character]
    private var pos: Int = 0

    init(_ input: String) {
        self.chars = Array(input)
    }

    func parse() throws -> ExpressionEvaluator.Node {
        let node = try parseTernary()
        skipWhitespace()
        return node
    }

    // MARK: - Precedence climbing

    private func parseTernary() throws -> ExpressionEvaluator.Node {
        let node = try parseOr()
        skipWhitespace()
        if peek() == "?" {
            advance()
            let consequent = try parseTernary()
            try expect(":")
            let alternate = try parseTernary()
            return .ternary(node, consequent, alternate)
        }
        return node
    }

    private func parseOr() throws -> ExpressionEvaluator.Node {
        var node = try parseAnd()
        while matchOperator("||") {
            let right = try parseAnd()
            node = .binary("||", node, right)
        }
        return node
    }

    private func parseAnd() throws -> ExpressionEvaluator.Node {
        var node = try parseEquality()
        while matchOperator("&&") {
            let right = try parseEquality()
            node = .binary("&&", node, right)
        }
        return node
    }

    private func parseEquality() throws -> ExpressionEvaluator.Node {
        var node = try parseComparison()
        while let op = matchAnyOperator(["===", "!==", "==", "!="]) {
            let right = try parseComparison()
            node = .binary(op, node, right)
        }
        return node
    }

    private func parseComparison() throws -> ExpressionEvaluator.Node {
        var node = try parseIn()
        while let op = matchAnyOperator(["<=", ">=", "<", ">"]) {
            let right = try parseIn()
            node = .binary(op, node, right)
        }
        return node
    }

    private func parseIn() throws -> ExpressionEvaluator.Node {
        var node = try parseAddition()
        skipWhitespace()
        if matchWord("in") {
            let right = try parseAddition()
            node = .binary("in", node, right)
        }
        return node
    }

    private func parseAddition() throws -> ExpressionEvaluator.Node {
        var node = try parseMultiplication()
        while let op = matchAnyOperator(["+", "-"]) {
            let right = try parseMultiplication()
            node = .binary(op, node, right)
        }
        return node
    }

    private func parseMultiplication() throws -> ExpressionEvaluator.Node {
        var node = try parseUnary()
        while let op = matchAnyOperator(["*", "/", "%"]) {
            let right = try parseUnary()
            node = .binary(op, node, right)
        }
        return node
    }

    private func parseUnary() throws -> ExpressionEvaluator.Node {
        skipWhitespace()
        if matchOperator("!") {
            let operand = try parseUnary()
            return .unary("!", operand)
        }
        if matchOperator("-") {
            let operand = try parseUnary()
            return .unary("-", operand)
        }
        if matchOperator("+") {
            let operand = try parseUnary()
            return .unary("+", operand)
        }
        if matchWord("typeof") {
            let operand = try parseUnary()
            return .unary("typeof", operand)
        }
        return try parseCallMember()
    }

    private func parseCallMember() throws -> ExpressionEvaluator.Node {
        var node = try parsePrimary()

        while true {
            skipWhitespace()
            if peek() == "." {
                advance()
                let name = try readIdentifier()
                node = .member(node, name)
            } else if peek() == "[" {
                advance()
                let index = try parseTernary()
                skipWhitespace()
                try expect("]")
                node = .computedMember(node, index)
            } else if peek() == "(" {
                advance()
                var args: [ExpressionEvaluator.Node] = []
                skipWhitespace()
                if peek() != ")" {
                    args.append(try parseTernary())
                    while peek() == "," {
                        advance()
                        args.append(try parseTernary())
                    }
                }
                skipWhitespace()
                try expect(")")
                node = .call(node, args)
            } else {
                break
            }
        }

        return node
    }

    private func parsePrimary() throws -> ExpressionEvaluator.Node {
        skipWhitespace()

        guard let ch = peek() else {
            throw ParseError.unexpectedEnd
        }

        // Number
        if ch.isNumber || (ch == "." && peekNext()?.isNumber == true) {
            return try parseNumber()
        }

        // String literal
        if ch == "'" || ch == "\"" {
            return try parseString()
        }

        // Array
        if ch == "[" {
            advance()
            var elements: [ExpressionEvaluator.Node] = []
            skipWhitespace()
            if peek() != "]" {
                elements.append(try parseTernary())
                while peek() == "," {
                    advance()
                    elements.append(try parseTernary())
                }
            }
            skipWhitespace()
            try expect("]")
            return .array(elements)
        }

        // Parenthesized expression
        if ch == "(" {
            advance()
            let node = try parseTernary()
            skipWhitespace()
            try expect(")")
            return node
        }

        // Identifier
        if ch.isLetter || ch == "_" || ch == "$" {
            let name = try readIdentifier()
            return .identifier(name)
        }

        throw ParseError.unexpectedCharacter(ch)
    }

    // MARK: - Token reading

    private func parseNumber() throws -> ExpressionEvaluator.Node {
        var str = ""
        while let ch = peek(), ch.isNumber || ch == "." {
            str.append(ch)
            advance()
        }
        guard let num = Double(str) else {
            throw ParseError.invalidNumber(str)
        }
        // Return Int if no decimal
        if !str.contains("."), let i = Int(str) {
            return .literal(i)
        }
        return .literal(num)
    }

    private func parseString() throws -> ExpressionEvaluator.Node {
        let quote = peek()!
        advance()
        var str = ""
        while let ch = peek(), ch != quote {
            if ch == "\\" {
                advance()
                if let escaped = peek() {
                    switch escaped {
                    case "n": str.append("\n")
                    case "t": str.append("\t")
                    case "\\": str.append("\\")
                    default: str.append(escaped)
                    }
                    advance()
                }
            } else {
                str.append(ch)
                advance()
            }
        }
        advance() // closing quote
        return .literal(str)
    }

    private func readIdentifier() throws -> String {
        var name = ""
        while let ch = peek(), ch.isLetter || ch.isNumber || ch == "_" || ch == "$" {
            name.append(ch)
            advance()
        }
        guard !name.isEmpty else {
            throw ParseError.expectedIdentifier
        }
        return name
    }

    // MARK: - Utilities

    private func peek() -> Character? {
        pos < chars.count ? chars[pos] : nil
    }

    private func peekNext() -> Character? {
        pos + 1 < chars.count ? chars[pos + 1] : nil
    }

    private func advance() {
        pos += 1
    }

    private func skipWhitespace() {
        while let ch = peek(), ch.isWhitespace { advance() }
    }

    private func matchOperator(_ op: String) -> Bool {
        skipWhitespace()
        let opChars = Array(op)
        for (i, c) in opChars.enumerated() {
            guard pos + i < chars.count, chars[pos + i] == c else { return false }
        }
        // Make sure the next char after the operator isn't part of a longer operator
        pos += opChars.count
        return true
    }

    private func matchAnyOperator(_ ops: [String]) -> String? {
        skipWhitespace()
        // Try longest operators first
        let sorted = ops.sorted { $0.count > $1.count }
        for op in sorted {
            let saved = pos
            if matchOperator(op) { return op }
            pos = saved
        }
        return nil
    }

    private func matchWord(_ word: String) -> Bool {
        let saved = pos
        let wordChars = Array(word)
        for (i, c) in wordChars.enumerated() {
            guard pos + i < chars.count, chars[pos + i] == c else {
                pos = saved
                return false
            }
        }
        // Make sure it's not part of a longer identifier
        let afterPos = pos + wordChars.count
        if afterPos < chars.count {
            let next = chars[afterPos]
            if next.isLetter || next.isNumber || next == "_" || next == "$" {
                pos = saved
                return false
            }
        }
        pos = afterPos
        return true
    }

    private func expect(_ ch: String) throws {
        skipWhitespace()
        let expected = Array(ch)
        for c in expected {
            guard peek() == c else {
                throw ParseError.expected(ch)
            }
            advance()
        }
    }

    enum ParseError: Error {
        case unexpectedEnd
        case unexpectedCharacter(Character)
        case invalidNumber(String)
        case expectedIdentifier
        case expected(String)
    }
}
