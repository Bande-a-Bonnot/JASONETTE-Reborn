import SwiftUI

/// Resolves layer-only style lengths against the containing viewport.
///
/// Jasonpedia layer fixtures use legacy strings such as `"10%"` and
/// `"50%-43"` for absolute layer placement. Keep that container-relative
/// arithmetic here instead of teaching every `AnyCodable.cgFloat` call site
/// about percentages without knowing the relevant axis length.
struct LayerLengthResolver {
    static func resolve(_ value: AnyCodable?, relativeTo containerLength: CGFloat) -> CGFloat? {
        guard let value else { return nil }
        if let exact = value.cgFloat { return exact }
        guard let string = value.string else { return nil }
        return resolve(string, relativeTo: containerLength)
    }

    static func resolve(_ string: String, relativeTo containerLength: CGFloat) -> CGFloat? {
        var expression = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if expression.hasPrefix("calc("), expression.hasSuffix(")") {
            expression = String(expression.dropFirst(5).dropLast())
        }
        expression = expression.replacingOccurrences(of: " ", with: "")
        expression = expression.replacingOccurrences(of: "\t", with: "")
        guard !expression.isEmpty else { return nil }

        var index = expression.startIndex
        var total: CGFloat = 0

        while index < expression.endIndex {
            var sign: CGFloat = 1
            if expression[index] == "+" {
                index = expression.index(after: index)
            } else if expression[index] == "-" {
                sign = -1
                index = expression.index(after: index)
            }

            let numberStart = index
            var sawDigit = false
            var sawDecimal = false
            while index < expression.endIndex {
                let character = expression[index]
                if character.isNumber {
                    sawDigit = true
                    index = expression.index(after: index)
                } else if character == ".", !sawDecimal {
                    sawDecimal = true
                    index = expression.index(after: index)
                } else {
                    break
                }
            }

            guard sawDigit,
                  let numeric = Double(expression[numberStart..<index]) else { return nil }

            var term = CGFloat(numeric)
            if index < expression.endIndex, expression[index] == "%" {
                term = containerLength * term / 100
                index = expression.index(after: index)
            }
            total += sign * term

            if index < expression.endIndex,
               expression[index] != "+",
               expression[index] != "-" {
                return nil
            }
        }

        return total
    }
}

/// Derived positioning values for a floating `body.layers` component.
///
/// A layer with both insets on the same axis should behave like CSS absolute
/// positioning: the layer is pinned between those edges and stretches across
/// the remaining space. Single-edge positioning keeps the historical natural
/// size + edge inset behavior.
struct LayerPositioning {
    let top: CGFloat?
    let bottom: CGFloat?
    let left: CGFloat?
    let right: CGFloat?

    init(style: JasonStyle, containerSize: CGSize? = nil) {
        if let containerSize {
            self.top = LayerLengthResolver.resolve(style.top, relativeTo: containerSize.height)
            self.bottom = LayerLengthResolver.resolve(style.bottom, relativeTo: containerSize.height)
            self.left = LayerLengthResolver.resolve(style.left, relativeTo: containerSize.width)
            self.right = LayerLengthResolver.resolve(style.right, relativeTo: containerSize.width)
        } else {
            self.top = style.top?.cgFloat
            self.bottom = style.bottom?.cgFloat
            self.left = style.left?.cgFloat
            self.right = style.right?.cgFloat
        }
    }

    var hasTop: Bool { top != nil }
    var hasBottom: Bool { bottom != nil }
    var hasLeft: Bool { left != nil }
    var hasRight: Bool { right != nil }

    var isUnpositioned: Bool {
        !hasTop && !hasBottom && !hasLeft && !hasRight
    }

    var stretchesHorizontally: Bool {
        hasLeft && hasRight
    }

    var stretchesVertically: Bool {
        hasTop && hasBottom
    }

    var insets: EdgeInsets {
        EdgeInsets(
            top: top ?? 0,
            leading: left ?? 0,
            bottom: bottom ?? 0,
            trailing: right ?? 0
        )
    }

    /// Determine the ZStack alignment based on which positioning properties
    /// are set. When both edges on an axis are set, the frame stretches on that
    /// axis, so the exact alignment on that axis is not visually significant.
    var alignment: Alignment {
        if isUnpositioned {
            return .center
        }
        let vertical: VerticalAlignment = hasBottom ? .bottom : .top
        let horizontal: HorizontalAlignment = hasRight && !hasLeft ? .trailing : .leading
        return Alignment(horizontal: horizontal, vertical: vertical)
    }
}
