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

    private static func renderArray(_ arr: [Any], context: [String: Any], depth: Int) -> Any {
        var result: [Any] = []
        var index = 0
        var containsOnlyConditionalBranches = !arr.isEmpty

        while index < arr.count {
            let item = arr[index]
            if let dict = item as? [String: Any],
               let firstBranch = ifBranch(in: dict),
               !hasInlineConditionalCompanion(in: dict) {
                var elseifs: [(String, Any)] = []
                var elseTemplate: Any?
                var next = index + 1

                while next < arr.count, let branchDict = arr[next] as? [String: Any] {
                    if let elseif = elseifBranch(in: branchDict) {
                        elseifs.append(elseif)
                        next += 1
                    } else if let fallback = elseBranch(in: branchDict) {
                        elseTemplate = fallback
                        next += 1
                        break
                    } else {
                        break
                    }
                }

                appendRendered(
                    applyDirective(
                        .ifCondition(
                            firstBranch.0,
                            firstBranch.1,
                            elseifs.isEmpty ? nil : elseifs,
                            elseTemplate
                        ),
                        template: dict,
                        context: context,
                        depth: depth + 1
                    ),
                    to: &result
                )
                index = next
                continue
            }

            if let dict = item as? [String: Any], let directive = findDirective(dict) {
                containsOnlyConditionalBranches = false
                appendRendered(
                    applyDirective(directive, template: dict, context: context, depth: depth + 1),
                    to: &result
                )
            } else {
                containsOnlyConditionalBranches = false
                result.append(render(item, context: context, depth: depth + 1))
            }
            index += 1
        }

        // Legacy Jasonette sometimes expresses a scalar conditional value as an
        // array of branch objects, e.g. `"url": [{"{{#if ...}}": "..."},
        // {"{{#else}}": "..."}]`. Collapse only scalar branch results; arrays
        // of rendered component objects must remain arrays.
        if containsOnlyConditionalBranches,
           result.count == 1,
           !(result[0] is [String: Any]),
           !(result[0] is [Any]) {
            return result[0]
        }
        return result
    }

    private static func appendRendered(_ rendered: Any, to result: inout [Any]) {
        if let arr = rendered as? [Any] {
            result.append(contentsOf: arr)
        } else {
            result.append(rendered)
        }
    }

    // MARK: - Object rendering

    private static func renderObject(_ dict: [String: Any], context: [String: Any], depth: Int) -> Any {
        // Check for template directives
        if let directive = findDirective(dict) {
            return applyDirective(directive, template: dict, context: context, depth: depth + 1)
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
            if let branch = ifBranch(key: key, value: dict[key]!) {
                let expr = branch.0
                let template = branch.1

                // Look for elseif and else in the same object.
                var elseifs: [(String, Any)] = []
                var elseTemplate: Any?
                for (k, v) in dict {
                    if let elseif = elseifBranch(key: k, value: v) {
                        elseifs.append(elseif)
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

    private static func ifBranch(in dict: [String: Any]) -> (String, Any)? {
        for (key, value) in dict {
            if let branch = ifBranch(key: key, value: value) { return branch }
        }
        return nil
    }

    private static func ifBranch(key: String, value: Any) -> (String, Any)? {
        guard key.hasPrefix("{{#if ") && key.hasSuffix("}}") else { return nil }
        let start = key.index(key.startIndex, offsetBy: 6)
        let end = key.index(key.endIndex, offsetBy: -2)
        return (String(key[start..<end]), value)
    }

    private static func elseifBranch(in dict: [String: Any]) -> (String, Any)? {
        for (key, value) in dict {
            if let branch = elseifBranch(key: key, value: value) { return branch }
        }
        return nil
    }

    private static func elseifBranch(key: String, value: Any) -> (String, Any)? {
        guard key.hasPrefix("{{#elseif ") && key.hasSuffix("}}") else { return nil }
        let start = key.index(key.startIndex, offsetBy: 10)
        let end = key.index(key.endIndex, offsetBy: -2)
        return (String(key[start..<end]), value)
    }

    private static func elseBranch(in dict: [String: Any]) -> Any? {
        dict["{{#else}}"]
    }

    private static func hasInlineConditionalCompanion(in dict: [String: Any]) -> Bool {
        dict.keys.contains("{{#else}}") || dict.keys.contains { $0.hasPrefix("{{#elseif ") && $0.hasSuffix("}}") }
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
                // Original Jasonette #each exposes object fields as direct identifiers
                // (e.g. {{title}}), while also preserving {{$jason}}/this access.
                if let object = item as? [String: Any] {
                    itemContext.merge(object) { _, itemValue in itemValue }
                }
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
