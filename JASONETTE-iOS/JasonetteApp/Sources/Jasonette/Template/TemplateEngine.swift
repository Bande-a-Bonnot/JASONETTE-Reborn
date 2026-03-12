import Foundation

/// Jasonette template engine — transforms JSON templates with data.
/// Handles `{{expr}}`, `{{#each items}}`, `{{#if cond}}`.
public enum TemplateEngine {
    static let maxDepth = 20
    private static let maxItems = 1000

    /// Render a template (Any JSON value) with a context.
    public static func render(_ template: Any, context: [String: Any]) -> Any {
        render(template, context: context, depth: 0)
    }

    private static func render(_ template: Any, context: [String: Any], depth: Int) -> Any {
        guard depth < maxDepth else { return template }
        if let str = template as? String {
            return interpolateString(str, context: context)
        }
        if let arr = template as? [Any] {
            return renderArray(arr, context: context, depth: depth)
        }
        if let dict = template as? [String: Any] {
            return renderObject(dict, context: context, depth: depth)
        }
        return template
    }

    // MARK: - String interpolation

    private static let exprPattern = try! NSRegularExpression(
        pattern: #"\{\{([^}]+(?:\}[^}]+)*)\}\}"#
    )

    private static func interpolateString(_ str: String, context: [String: Any]) -> Any {
        guard str.contains("{{") else { return str }
        let range = NSRange(str.startIndex..., in: str)
        let matches = exprPattern.matches(in: str, range: range)

        if matches.isEmpty { return str }

        // Single expression covering entire string — return typed value
        if matches.count == 1,
           let matchRange = Range(matches[0].range, in: str),
           matchRange == str.startIndex..<str.endIndex,
           let exprRange = Range(matches[0].range(at: 1), in: str) {
            let expr = String(str[exprRange])
            return ExpressionEvaluator.evaluate(expr, context: context) ?? ""
        }

        // Multiple expressions — concatenate as string
        var result = str
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let exprRange = Range(match.range(at: 1), in: result) else { continue }
            let expr = String(result[exprRange])
            let value = ExpressionEvaluator.evaluate(expr, context: context)
            result.replaceSubrange(fullRange, with: "\(value ?? "")")
        }
        return result
    }

    // MARK: - Array rendering

    private static func renderArray(_ arr: [Any], context: [String: Any], depth: Int) -> [Any] {
        var result: [Any] = []
        for item in arr {
            if let dict = item as? [String: Any], let directive = findDirective(dict) {
                let rendered = applyDirective(directive, template: dict, context: context, depth: depth + 1)
                if let arr = rendered as? [Any] {
                    result.append(contentsOf: arr)
                } else {
                    result.append(rendered)
                }
            } else {
                result.append(render(item, context: context, depth: depth + 1))
            }
        }
        return result
    }

    // MARK: - Object rendering

    private static func renderObject(_ dict: [String: Any], context: [String: Any], depth: Int) -> Any {
        // Check for template directives
        if let directive = findDirective(dict) {
            return applyDirective(directive, template: dict, context: context, depth: depth)
        }

        var result: [String: Any] = [:]
        for (key, value) in dict {
            let renderedKey = interpolateString(key, context: context)
            let keyStr = renderedKey as? String ?? "\(renderedKey)"
            result[keyStr] = render(value, context: context, depth: depth + 1)
        }
        return result
    }

    // MARK: - Directives

    private enum Directive {
        case each(String, Any) // {{#each expr}}: template
        case ifCondition(String, Any, [(String, Any)]?, Any?) // {{#if}}: val, elseifs, else
    }

    private static func findDirective(_ dict: [String: Any]) -> Directive? {
        for key in dict.keys {
            if key.hasPrefix("{{#each ") && key.hasSuffix("}}") {
                let start = key.index(key.startIndex, offsetBy: 8)
                let end = key.index(key.endIndex, offsetBy: -2)
                let expr = String(key[start..<end])
                return .each(expr, dict[key]!)
            }
            if key.hasPrefix("{{#if ") && key.hasSuffix("}}") {
                let start = key.index(key.startIndex, offsetBy: 6)
                let end = key.index(key.endIndex, offsetBy: -2)
                let expr = String(key[start..<end])
                let template = dict[key]!

                // Look for elseif and else
                var elseifs: [(String, Any)] = []
                var elseTemplate: Any?
                for (k, v) in dict {
                    if k.hasPrefix("{{#elseif ") && k.hasSuffix("}}") {
                        let s = k.index(k.startIndex, offsetBy: 10)
                        let e = k.index(k.endIndex, offsetBy: -2)
                        elseifs.append((String(k[s..<e]), v))
                    }
                    if k == "{{#else}}" {
                        elseTemplate = v
                    }
                }

                return .ifCondition(
                    expr, template,
                    elseifs.isEmpty ? nil : elseifs,
                    elseTemplate
                )
            }
        }
        return nil
    }

    private static func applyDirective(
        _ directive: Directive, template: [String: Any], context: [String: Any], depth: Int
    ) -> Any {
        switch directive {
        case .each(let expr, let itemTemplate):
            let value = ExpressionEvaluator.evaluate(expr, context: context)
            guard let items = value as? [Any] else { return [] }

            let truncated = items.count > maxItems ? Array(items.prefix(maxItems)) : items
            #if DEBUG
            if items.count > maxItems {
                print("[Jasonette] #each: truncated \(items.count) items to \(maxItems)")
            }
            #endif
            var result: [Any] = []
            for (index, item) in truncated.enumerated() {
                var itemContext = context
                itemContext["$jason"] = item
                itemContext["$index"] = index
                if let root = context["$jason"] {
                    itemContext["$root"] = root
                }
                result.append(render(itemTemplate, context: itemContext, depth: depth + 1))
            }
            return result

        case .ifCondition(let expr, let thenTemplate, let elseifs, let elseTemplate):
            let condResult = ExpressionEvaluator.evaluate(expr, context: context)
            if ExpressionEvaluator.isTruthy(condResult) {
                return render(thenTemplate, context: context, depth: depth + 1)
            }
            if let elseifs = elseifs {
                for (elseifExpr, elseifTemplate) in elseifs {
                    let elseifResult = ExpressionEvaluator.evaluate(elseifExpr, context: context)
                    if ExpressionEvaluator.isTruthy(elseifResult) {
                        return render(elseifTemplate, context: context, depth: depth + 1)
                    }
                }
            }
            if let elseTemplate = elseTemplate {
                return render(elseTemplate, context: context, depth: depth + 1)
            }
            // Return empty array so #if false in array context produces no items
            return [Any]()
        }
    }
}
