import SwiftUI

enum LayoutDirection {
    case vertical
    case horizontal
}

/// Renders child components in a vertical or horizontal stack.
struct LayoutView: View {
    let direction: LayoutDirection
    let components: [JasonComponent]
    let headStyles: [String: JasonStyle]
    let style: JasonStyle?
    let onHref: ((JasonHref) -> Void)?
    let onAction: ((JasonAction) -> Void)?

    var body: some View {
        let spacing = style?.spacing?.cgFloat ?? 8

        switch direction {
        case .vertical:
            VStack(alignment: alignment, spacing: spacing) {
                ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                    ComponentView(component, headStyles: headStyles, onHref: onHref, onAction: onAction)
                }
            }
        case .horizontal:
            HStack(alignment: vAlignment, spacing: spacing) {
                ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                    ComponentView(component, headStyles: headStyles, onHref: onHref, onAction: onAction)
                }
            }
        }
    }

    private var alignment: HorizontalAlignment {
        switch style?.align {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private var vAlignment: VerticalAlignment {
        switch style?.align {
        case "center": return .center
        case "bottom": return .bottom
        default: return .top
        }
    }
}
