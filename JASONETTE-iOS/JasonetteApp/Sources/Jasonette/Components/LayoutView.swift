import SwiftUI

enum LayoutDirection {
    case vertical
    case horizontal
}

enum HorizontalChildWidth: Equatable {
    case flexible
    case fixed(CGFloat)
    case intrinsic

    init(style: JasonStyle) {
        guard let width = style.width else {
            self = .flexible
            return
        }
        guard let points = width.cgFloat, points.isFinite else {
            // String widths such as "100%" are not supported by cgFloat.
            // Keep their current intrinsic behavior instead of treating them
            // as a newly implemented percentage constraint.
            self = .intrinsic
            return
        }
        self = .fixed(points)
    }
}

enum HorizontalLayoutSizing {
    static func viewportWidth(
        authoredWidth: CGFloat?,
        measuredContentWidth: CGFloat?,
        paddingLeft: CGFloat,
        paddingRight: CGFloat
    ) -> CGFloat? {
        if let authoredWidth, authoredWidth.isFinite {
            return max(0, authoredWidth - paddingLeft - paddingRight)
        }
        guard let measuredContentWidth, measuredContentWidth.isFinite else { return nil }
        return max(0, measuredContentWidth)
    }

    static func needsHorizontalScroll(viewportWidth: CGFloat?, measuredRowWidth: CGFloat?) -> Bool {
        guard
            let viewportWidth,
            let measuredRowWidth,
            viewportWidth.isFinite,
            measuredRowWidth.isFinite,
            viewportWidth > 0
        else {
            return false
        }
        return measuredRowWidth > viewportWidth + 0.5
    }

    static func measuredRowWidth(
        proposalWidth: CGFloat?,
        childWidths: [CGFloat],
        spacing: CGFloat
    ) -> CGFloat {
        let contentWidth = childWidths.reduce(0, +) + spacing * CGFloat(max(0, childWidths.count - 1))
        return proposalWidth.flatMap { $0.isFinite ? $0 : nil }.map { max($0, contentWidth) } ?? contentWidth
    }

    static func childWidths(
        containerWidth: CGFloat?,
        paddingLeft: CGFloat,
        paddingRight: CGFloat,
        spacing: CGFloat,
        widthModes: [HorizontalChildWidth],
        idealWidths: [CGFloat],
        distribution: String?
    ) -> [CGFloat] {
        guard !widthModes.isEmpty else { return [] }

        let ideals = widthModes.indices.map { index in
            index < idealWidths.count && idealWidths[index].isFinite
                ? max(0, idealWidths[index])
                : 0
        }

        guard let containerWidth, containerWidth.isFinite else {
            return widthModes.indices.map { index in
                switch widthModes[index] {
                case .fixed(let width): return max(0, width)
                case .flexible, .intrinsic: return ideals[index]
                }
            }
        }

        let totalSpacing = spacing * CGFloat(max(0, widthModes.count - 1))
        let availableWidth = max(0, containerWidth - paddingLeft - paddingRight - totalSpacing)
        var result = Array(repeating: CGFloat.zero, count: widthModes.count)
        var flexibleIndices: [Int] = []
        var reservedWidth: CGFloat = 0

        for index in widthModes.indices {
            switch widthModes[index] {
            case .fixed(let width):
                let width = max(0, width)
                result[index] = width
                reservedWidth += width
            case .intrinsic:
                result[index] = ideals[index]
                reservedWidth += ideals[index]
            case .flexible:
                flexibleIndices.append(index)
            }
        }

        guard !flexibleIndices.isEmpty else { return result }
        let remainingWidth = max(0, availableWidth - reservedWidth)
        if distribution == "equalsize" {
            let share = remainingWidth / CGFloat(flexibleIndices.count)
            for index in flexibleIndices { result[index] = share }
            return result
        }

        let totalIdealWidth = flexibleIndices.reduce(CGFloat.zero) { $0 + ideals[$1] }
        if totalIdealWidth > 0 {
            for index in flexibleIndices {
                result[index] = remainingWidth * ideals[index] / totalIdealWidth
            }
        } else {
            let share = remainingWidth / CGFloat(flexibleIndices.count)
            for index in flexibleIndices { result[index] = share }
        }
        return result
    }
}

private struct HorizontalViewportWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = max(value ?? next, next) }
    }
}

private struct HorizontalRowWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = max(value ?? next, next) }
    }
}

private struct HorizontalRowLayout: Layout {
    let spacing: CGFloat
    let distribution: String?
    let paddingLeft: CGFloat
    let paddingRight: CGFloat
    let alignment: String?
    let widthModes: [HorizontalChildWidth]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = allocatedWidths(proposedContentWidth: proposal.width, subviews: subviews)
        let sizes = measuredSizes(widths: widths, subviews: subviews)
        let width = HorizontalLayoutSizing.measuredRowWidth(
            proposalWidth: proposal.width,
            childWidths: widths,
            spacing: spacing
        )
        return CGSize(width: width, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = allocatedWidths(proposedContentWidth: bounds.width, subviews: subviews)
        let sizes = measuredSizes(widths: widths, subviews: subviews)
        var x = bounds.minX

        for index in subviews.indices {
            let size = sizes[index]
            let y: CGFloat
            switch alignment {
            case "center": y = bounds.minY + (bounds.height - size.height) / 2
            case "bottom": y = bounds.maxY - size.height
            default: y = bounds.minY
            }

            let childProposal = ProposedViewSize(width: widths[index], height: nil)
            subviews[index].place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: childProposal
            )
            x += widths[index] + spacing
        }
    }

    private func allocatedWidths(proposedContentWidth: CGFloat?, subviews: Subviews) -> [CGFloat] {
        let idealWidths = subviews.map {
            $0.sizeThatFits(.unspecified).width
        }
        let containerWidth = proposedContentWidth.flatMap { width in
            width.isFinite ? width + paddingLeft + paddingRight : nil
        }
        let effectiveModes = subviews.indices.map { index in
            index < widthModes.count ? widthModes[index] : .flexible
        }
        return HorizontalLayoutSizing.childWidths(
            containerWidth: containerWidth,
            paddingLeft: paddingLeft,
            paddingRight: paddingRight,
            spacing: spacing,
            widthModes: effectiveModes,
            idealWidths: idealWidths,
            distribution: distribution
        )
    }

    private func measuredSizes(widths: [CGFloat], subviews: Subviews) -> [CGSize] {
        subviews.indices.map { index in
            subviews[index].sizeThatFits(ProposedViewSize(width: widths[index], height: nil))
        }
    }
}

/// Renders child components in a vertical or horizontal stack.
struct LayoutView: View {
    let direction: LayoutDirection
    let components: [JasonComponent]
    let headStyles: [String: JasonStyle]
    let style: JasonStyle?
    let onHref: ((JasonHref) -> Void)?
    let onAction: ((JasonAction) -> Void)?
    let documentURL: URL?
    @State private var horizontalViewportWidth: CGFloat?
    @State private var horizontalRowWidth: CGFloat?

    var body: some View {
        let spacing = style?.spacing?.cgFloat ?? 8

        switch direction {
        case .vertical:
            VStack(alignment: alignment, spacing: spacing) {
                ForEach(components.indices, id: \.self) { index in
                    ComponentView(
                        components[index],
                        headStyles: headStyles,
                        onHref: onHref,
                        onAction: onAction,
                        documentURL: documentURL
                    )
                }
            }
        case .horizontal:
            ZStack(alignment: .topLeading) {
                if HorizontalLayoutSizing.needsHorizontalScroll(
                    viewportWidth: horizontalScrollViewportWidth,
                    measuredRowWidth: horizontalRowWidth
                ) {
                    ScrollView(.horizontal) {
                        horizontalRow(spacing: spacing)
                    }
                    .frame(width: horizontalScrollViewportWidth)
                } else {
                    horizontalRow(spacing: spacing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: HorizontalViewportWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            }
            .onPreferenceChange(HorizontalViewportWidthPreferenceKey.self) { width in
                guard let width, width.isFinite, width > 0 else { return }
                horizontalViewportWidth = width
            }
            .onPreferenceChange(HorizontalRowWidthPreferenceKey.self) { width in
                guard let width, width.isFinite else { return }
                horizontalRowWidth = width
            }
        }
    }

    private var horizontalScrollViewportWidth: CGFloat? {
        HorizontalLayoutSizing.viewportWidth(
            authoredWidth: style?.width?.cgFloat,
            measuredContentWidth: horizontalViewportWidth,
            paddingLeft: horizontalPaddingLeft,
            paddingRight: horizontalPaddingRight
        )
    }

    private var horizontalPaddingLeft: CGFloat {
        style?.paddingLeft?.cgFloat ?? style?.padding?.cgFloat ?? 0
    }

    private var horizontalPaddingRight: CGFloat {
        style?.paddingRight?.cgFloat ?? style?.padding?.cgFloat ?? 0
    }

    private func horizontalRow(spacing: CGFloat) -> some View {
        HorizontalRowLayout(
            spacing: spacing,
            distribution: style?.distribution,
            paddingLeft: horizontalPaddingLeft,
            paddingRight: horizontalPaddingRight,
            alignment: style?.align,
            widthModes: components.map { component in
                HorizontalChildWidth(style: JasonStyle.resolve(for: component, headStyles: headStyles))
            }
        ) {
            horizontalComponents()
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: HorizontalRowWidthPreferenceKey.self,
                    value: proxy.size.width
                )
            }
        }
    }

    @ViewBuilder
    private func horizontalComponents() -> some View {
        ForEach(components.indices, id: \.self) { index in
            ComponentView(
                components[index],
                headStyles: headStyles,
                onHref: onHref,
                onAction: onAction,
                documentURL: documentURL
            )
            .transformPreference(HorizontalViewportWidthPreferenceKey.self) { $0 = nil }
            .transformPreference(HorizontalRowWidthPreferenceKey.self) { $0 = nil }
        }
    }

    private var alignment: HorizontalAlignment {
        switch style?.align {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

}
