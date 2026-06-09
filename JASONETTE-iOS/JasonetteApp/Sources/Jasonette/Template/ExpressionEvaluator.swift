import Foundation

/// Evaluates Jasonette template expressions like `{{$jason.name}}`.
/// Uses a simple recursive-descent parser instead of a full JS engine.
public enum ExpressionEvaluator {
    // Only accessed from @MainActor context (TemplateEngine → JasonetteViewModel.render)
    private static var _nodeCache: [String: Node] = [:]
    private static let maxCacheSize = 256
    private static let maxDepth = 20

    /// Evaluate an expression string against a context.
    public static func evaluate(_ expression: String, context: [String: Any]) -> Any? {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let legacyResult = evaluateLegacyMutationExpression(trimmed, context: context) {
            return legacyResult
        }
        if let legacyResult = evaluateLegacyDateToStringExpression(trimmed, context: context) {
            return legacyResult
        }

        if let cached = _nodeCache[trimmed] {
            return resolve(cached, context: context)
        }

        let parser = ExpressionParser(trimmed)
        do {
            let node = try parser.parse()
            if _nodeCache.count >= maxCacheSize {
                _nodeCache.removeAll(keepingCapacity: true)
            }
            _nodeCache[trimmed] = node
            return resolve(node, context: context)
        } catch {
            return nil
        }
    }

    // MARK: - Legacy expression compatibility

    /// Supports the small legacy Jasonette mutation idiom still present in
    /// Jasonpedia fixtures, e.g.:
    /// `var new_style = $get.style; new_style['move']='true'; return new_style;`
    ///
    /// The modern expression parser intentionally does not execute arbitrary
    /// JavaScript, so this recognizes only copy-one-$get-dictionary, set-one-key,
    /// return-the-copy. That keeps the dynamic layer demo working without adding
    /// a JS runtime or allowing arbitrary code execution.
    private static func evaluateLegacyMutationExpression(_ expression: String, context: [String: Any]) -> Any? {
        let statements = expression
            .split(separator: ";", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard statements.count == 3,
              statements[0].hasPrefix("var ")
        else { return nil }

        let declaration = String(statements[0].dropFirst(4))
        let declarationParts = declaration.split(separator: "=", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard declarationParts.count == 2 else { return nil }
        let variableName = declarationParts[0]
        let source = declarationParts[1]
        guard source.hasPrefix("$get.") else { return nil }
        let sourceKey = String(source.dropFirst(5))

        guard let assignment = parseLegacyAssignment(statements[1], variableName: variableName),
              statements[2] == "return \(variableName)",
              let getContext = context["$get"] as? [String: Any],
              var base = getContext[sourceKey] as? [String: Any]
        else { return nil }

        base[assignment.key] = assignment.value
        return base
    }

    /// Supports the legacy Jasonpedia datepicker success expression:
    /// `(new Date(parseInt($jason.value) * 1000)).toString()`.
    ///
    /// This is intentionally narrow: it unwraps one parenthesized `new Date(...)`
    /// followed by `.toString()`, evaluates only the timestamp expression through
    /// the safe parser, and formats that date without executing arbitrary JS.
    private static func evaluateLegacyDateToStringExpression(_ expression: String, context: [String: Any]) -> Any? {
        let suffix = ".toString()"
        guard expression.hasSuffix(suffix) else { return nil }

        var constructor = String(expression.dropLast(suffix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if constructor.hasPrefix("("), constructor.hasSuffix(")") {
            constructor = String(constructor.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let prefix = "new Date("
        guard constructor.hasPrefix(prefix), constructor.hasSuffix(")") else { return nil }
        let timestampExpression = String(constructor.dropFirst(prefix.count).dropLast())
        guard let rawTimestamp = evaluate(timestampExpression, context: context),
              var timestamp = toDouble(rawTimestamp) else { return nil }
        if abs(timestamp) > 10_000_000_000 {
            timestamp /= 1_000
        }
        return Date(timeIntervalSince1970: timestamp).description
    }

    private static func parseLegacyAssignment(_ statement: String, variableName: String) -> (key: String, value: String)? {
        guard statement.hasPrefix(variableName) else { return nil }
        let remainder = statement.dropFirst(variableName.count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard remainder.hasPrefix("[") else { return nil }

        let quoteStartIndex = remainder.index(after: remainder.startIndex)
        guard quoteStartIndex < remainder.endIndex,
              remainder[quoteStartIndex] == "'" || remainder[quoteStartIndex] == "\""
        else { return nil }
        let quote = remainder[quoteStartIndex]
        guard let quoteEndIndex = remainder[remainder.index(after: quoteStartIndex)...].firstIndex(of: quote) else { return nil }
        let key = String(remainder[remainder.index(after: quoteStartIndex)..<quoteEndIndex])

        guard let equalsIndex = remainder.firstIndex(of: "=") else { return nil }
        let rawValue = remainder[remainder.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.count >= 2,
              let first = rawValue.first,
              let last = rawValue.last,
              (first == "'" || first == "\""),
              first == last
        else { return nil }
        return (key, String(rawValue.dropFirst().dropLast()))
    }

    // MARK: - AST Node Types

    indirect enum Node {
        case literal(Any)
        case identifier(String)
        case member(Node, String)
        case computedMember(Node, Node)
        case binary(String, Node, Node)
        case unary(String, Node)
        case ternary(Node, Node, Node)
        case call(Node, [Node])
        case array([Node])
    }

    // MARK: - Safe function allowlist

    private static let safeFunctions: [String: ([Any]) -> Any?] = [
        "Math.floor": { args in args.first.flatMap { toDouble($0) }.map { Int(floor($0)) } },
        "Math.ceil": { args in args.first.flatMap { toDouble($0) }.map { Int(ceil($0)) } },
        "Math.round": { args in args.first.flatMap { toDouble($0) }.map { Int(Foundation.round($0)) } },
        "Math.abs": { args in args.first.flatMap { toDouble($0) }.map { abs($0) } },
        "Math.min": { args in
            let nums = args.compactMap { toDouble($0) }
            return nums.min()
        },
        "Math.max": { args in
            let nums = args.compactMap { toDouble($0) }
            return nums.max()
        },
        "parseInt": { args in args.first.flatMap { toDouble($0) }.map { Int($0) } },
        "parseFloat": { args in args.first.flatMap { toDouble($0) } },
        "String": { args in args.first.map { "\($0)" } },
        "Number": { args in args.first.flatMap { toDouble($0) } },
        "Array.isArray": { args in args.first is [Any] },
        "randomcolor": { _ in
            String(format: "#%06X", Int.random(in: 0...0xFFFFFF))
        },
        "JSON.stringify": { args in
            guard let val = args.first else { return nil }
            guard JSONSerialization.isValidJSONObject(val) else { return "\(val)" }
            if let data = try? JSONSerialization.data(
                withJSONObject: val, options: [.sortedKeys]
            ) {
                return String(data: data, encoding: .utf8)
            }
            return "\(val)"
        },
    ]

    /// Property blocklist for security.
    private static let blockedProperties: Set<String> = [
        "__proto__", "constructor", "prototype",
    ]

    // MARK: - Resolution

    static func resolve(_ node: Node, context: [String: Any], depth: Int = 0) -> Any? {
        guard depth < maxDepth else { return nil }

        switch node {
        case .literal(let v):
            return v

        case .identifier(let name):
            if name == "true" { return true }
            if name == "false" { return false }
            if name == "null" || name == "undefined" { return NSNull() }
            if name == "this" { return context["$jason"] }
            return context[name]

        case .member(let obj, let prop):
            guard !blockedProperties.contains(prop) else { return nil }
            if case .identifier(let name) = obj {
                // Handle Math.*, JSON.* as function namespaces
                let fullName = "\(name).\(prop)"
                if safeFunctions[fullName] != nil {
                    return fullName // Return as callable reference
                }
            }
            guard let objVal = resolve(obj, context: context, depth: depth + 1) else { return nil }
            return accessProperty(objVal, key: prop)

        case .computedMember(let obj, let prop):
            guard let objVal = resolve(obj, context: context, depth: depth + 1) else { return nil }
            guard let key = resolve(prop, context: context, depth: depth + 1) else { return nil }
            if let k = key as? String, blockedProperties.contains(k) { return nil }
            if let arr = objVal as? [Any], let idx = toInt(key), idx >= 0, idx < arr.count {
                return arr[idx]
            }
            if let dict = objVal as? [String: Any], let k = key as? String {
                return dict[k]
            }
            return nil

        case .binary(let op, let left, let right):
            return evaluateBinary(op, left: left, right: right, context: context, depth: depth)

        case .unary(let op, let operand):
            let val = resolve(operand, context: context, depth: depth + 1)
            switch op {
            case "!": return !isTruthy(val)
            case "-": return toDouble(val).map { -$0 }
            case "+": return toDouble(val)
            case "typeof": return typeofValue(val)
            default: return nil
            }

        case .ternary(let cond, let consequent, let alternate):
            let condVal = resolve(cond, context: context, depth: depth + 1)
            if isTruthy(condVal) {
                return resolve(consequent, context: context, depth: depth + 1)
            } else {
                return resolve(alternate, context: context, depth: depth + 1)
            }

        case .call(let callee, let args):
            let resolvedArgs = args.compactMap { resolve($0, context: context, depth: depth + 1) }
            if let ref = resolve(callee, context: context, depth: depth + 1) as? String,
               let fn = safeFunctions[ref] {
                return fn(resolvedArgs)
            }
            // Direct function name
            if case .identifier(let name) = callee, let fn = safeFunctions[name] {
                return fn(resolvedArgs)
            }
            return nil

        case .array(let elements):
            return elements.compactMap { resolve($0, context: context, depth: depth + 1) }
        }
    }

    // MARK: - Helpers

    private static func evaluateBinary(
        _ op: String, left: Node, right: Node,
        context: [String: Any], depth: Int
    ) -> Any? {
        // Short-circuit for logical operators
        if op == "&&" {
            let l = resolve(left, context: context, depth: depth + 1)
            return isTruthy(l) ? resolve(right, context: context, depth: depth + 1) : l
        }
        if op == "||" {
            let l = resolve(left, context: context, depth: depth + 1)
            return isTruthy(l) ? l : resolve(right, context: context, depth: depth + 1)
        }

        let l = resolve(left, context: context, depth: depth + 1)
        let r = resolve(right, context: context, depth: depth + 1)

        switch op {
        case "+":
            if let ls = l as? String { return ls + "\(r ?? "")" }
            if let rs = r as? String { return "\(l ?? "")" + rs }
            if let li = l as? Int, let ri = r as? Int { return li + ri }
            if let ld = toDouble(l), let rd = toDouble(r) { return ld + rd }
            return nil
        case "-":
            if let li = l as? Int, let ri = r as? Int { return li - ri }
            return applyArith(l, r, -)
        case "*":
            if let li = l as? Int, let ri = r as? Int { return li * ri }
            return applyArith(l, r, *)
        case "/":
            guard let rd = toDouble(r), rd != 0 else { return nil }
            if let li = l as? Int, let ri = r as? Int, li % ri == 0 { return li / ri }
            return toDouble(l).map { $0 / rd }
        case "%":
            if let li = l as? Int, let ri = r as? Int, ri != 0 { return li % ri }
            guard let rd = toDouble(r), rd != 0 else { return nil }
            return toDouble(l).map { $0.truncatingRemainder(dividingBy: rd) }
        case "==", "===":
            return looseEqual(l, r)
        case "!=", "!==":
            return !looseEqual(l, r)
        case "<": return compareValues(l, r).map { $0 < 0 }
        case "<=": return compareValues(l, r).map { $0 <= 0 }
        case ">": return compareValues(l, r).map { $0 > 0 }
        case ">=": return compareValues(l, r).map { $0 >= 0 }
        case "in":
            guard let key = l as? String else { return false }
            if let dict = r as? [String: Any] { return dict[key] != nil }
            return false
        default:
            return nil
        }
    }

    static func isTruthy(_ value: Any?) -> Bool {
        guard let v = value else { return false }
        if v is NSNull { return false }
        if let b = v as? Bool { return b }
        if let n = v as? Int { return n != 0 }
        if let n = v as? Double { return n != 0 }
        if let s = v as? String { return !s.isEmpty }
        if let a = v as? [Any] { return !a.isEmpty }
        return true
    }

    private static func toDouble(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String { return Double(s) }
        return nil
    }

    private static func toInt(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String { return Int(s) }
        return nil
    }

    private static func accessProperty(_ obj: Any, key: String) -> Any? {
        if let dict = obj as? [String: Any] { return dict[key] }
        if let dict = obj as? [String: AnyCodable] { return dict[key]?.value }
        if key == "length" {
            if let arr = obj as? [Any] { return arr.count }
            if let s = obj as? String { return s.count }
        }
        return nil
    }

    private static func applyArith(_ l: Any?, _ r: Any?, _ op: (Double, Double) -> Double) -> Any? {
        guard let ld = toDouble(l), let rd = toDouble(r) else { return nil }
        return op(ld, rd)
    }

    private static func looseEqual(_ l: Any?, _ r: Any?) -> Bool {
        if l == nil && r == nil { return true }
        if l is NSNull && r is NSNull { return true }
        if let ls = l as? String, let rs = r as? String { return ls == rs }
        if let ld = toDouble(l), let rd = toDouble(r) { return ld == rd }
        if let lb = l as? Bool, let rb = r as? Bool { return lb == rb }
        return false
    }

    private static func compareValues(_ l: Any?, _ r: Any?) -> Int? {
        if let ld = toDouble(l), let rd = toDouble(r) {
            return ld < rd ? -1 : (ld > rd ? 1 : 0)
        }
        if let ls = l as? String, let rs = r as? String {
            return ls < rs ? -1 : (ls > rs ? 1 : 0)
        }
        return nil
    }

    private static func typeofValue(_ v: Any?) -> String {
        guard let v = v else { return "undefined" }
        if v is NSNull { return "object" }
        if v is Bool { return "boolean" }
        if v is Int || v is Double { return "number" }
        if v is String { return "string" }
        if v is [Any] { return "object" }
        if v is [String: Any] { return "object" }
        return "undefined"
    }
}
