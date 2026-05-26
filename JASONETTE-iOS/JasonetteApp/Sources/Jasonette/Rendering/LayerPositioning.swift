import SwiftUI

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

    init(style: JasonStyle) {
        self.top = style.top?.cgFloat
        self.bottom = style.bottom?.cgFloat
        self.left = style.left?.cgFloat
        self.right = style.right?.cgFloat
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
