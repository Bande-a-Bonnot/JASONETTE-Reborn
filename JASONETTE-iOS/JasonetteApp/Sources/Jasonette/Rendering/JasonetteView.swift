import SwiftUI

// MARK: - Conditional modifier

private extension View {
    @ViewBuilder
    func ifLet<T, Modified: View>(_ value: T?, transform: (Self, T) -> Modified) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

/// Main view that renders a complete Jasonette document.
@MainActor
public struct JasonetteView: View {
    @StateObject private var viewModel: JasonetteViewModel

    public init(url: URL) {
        _viewModel = StateObject(wrappedValue: JasonetteViewModel(url: url))
    }

    public init(document: JasonDocument) {
        _viewModel = StateObject(wrappedValue: JasonetteViewModel(document: document))
    }

    public var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                documentBody
            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(message)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Retry") { viewModel.reload() }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .alert(item: $viewModel.alertConfig) { config in
            Alert(
                title: Text(config.title),
                message: config.description.map { Text($0) },
                dismissButton: .default(Text("OK"))
            )
        }
        .environmentObject(viewModel.stateManager)
    }

    @ViewBuilder
    private var documentBody: some View {
        let root = viewModel.renderedRoot
        let head = root?.head
        let body = root?.body
        let headStyles = head?.styles ?? [:]
        let headerStyle = body?.header?.style

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Sections
                        if let sections = body?.sections {
                            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                                sectionView(section, headStyles: headStyles)
                            }
                        }
                    }
                }
                .refreshable { await viewModel.handlePull() }

                // Footer
                if let footer = body?.footer {
                    footerView(footer, headStyles: headStyles)
                }
            }

            // Layers — float above body content as positioned overlays
            if let layers = body?.layers {
                ForEach(Array(layers.enumerated()), id: \.offset) { _, component in
                    layerView(component, headStyles: headStyles)
                }
            }
        }
        .navigationTitle(head?.title ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .ifLet(headerStyle?.background.flatMap { Color(css: $0) }) { view, color in
            view
                .toolbarBackground(color, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        #endif
        .toolbar {
            if let menu = body?.header?.menu, let text = menu.text, !text.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(text) {
                        if let href = menu.href {
                            viewModel.handleHref(href)
                        } else if let action = menu.action {
                            viewModel.handleAction(action)
                        }
                    }
                }
            }
        }
        .onDisappear { viewModel.actionDispatcher.invalidateAllTimers() }
    }

    @ViewBuilder
    private func layerView(_ component: JasonComponent, headStyles: [String: JasonStyle]) -> some View {
        let style = resolveLayerStyle(component, headStyles: headStyles)
        let hasTop = style.top?.cgFloat != nil
        let hasBottom = style.bottom?.cgFloat != nil
        let hasLeft = style.left?.cgFloat != nil
        let hasRight = style.right?.cgFloat != nil
        let alignment = layerAlignment(hasTop: hasTop, hasBottom: hasBottom, hasLeft: hasLeft, hasRight: hasRight)

        ZStack(alignment: alignment) {
            Color.clear
                .allowsHitTesting(false)
            ComponentView(
                component,
                headStyles: headStyles,
                onHref: { viewModel.handleHref($0) },
                onAction: { viewModel.handleAction($0) }
            )
            .ifLet(style.top?.cgFloat) { view, value in
                view.padding(.top, value)
            }
            .ifLet(style.bottom?.cgFloat) { view, value in
                view.padding(.bottom, value)
            }
            .ifLet(style.left?.cgFloat) { view, value in
                view.padding(.leading, value)
            }
            .ifLet(style.right?.cgFloat) { view, value in
                view.padding(.trailing, value)
            }
        }
        .allowsHitTesting(true)
    }

    /// Resolve class + inline style for a layer component (mirrors JasonStyleModifier.resolved).
    private func resolveLayerStyle(_ component: JasonComponent, headStyles: [String: JasonStyle]) -> JasonStyle {
        var base = JasonStyle()
        if let cls = component.class {
            let classNames = cls.split(separator: " ").map(String.init)
            for name in classNames {
                if let headStyle = headStyles[name] {
                    base = base.merging(headStyle)
                }
            }
        }
        guard let inline = component.style else { return base }
        return base.merging(inline)
    }

    /// Determine the ZStack alignment based on which positioning properties are set.
    private func layerAlignment(hasTop: Bool, hasBottom: Bool, hasLeft: Bool, hasRight: Bool) -> Alignment {
        if !hasTop && !hasBottom && !hasLeft && !hasRight {
            return .center
        }
        let vertical: VerticalAlignment = hasBottom ? .bottom : .top
        let horizontal: HorizontalAlignment = hasRight && !hasLeft ? .trailing : .leading
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    @ViewBuilder
    private func sectionView(_ section: JasonSection, headStyles: [String: JasonStyle]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = section.header {
                ComponentView(
                    header,
                    headStyles: headStyles,
                    onHref: { viewModel.handleHref($0) },
                    onAction: { viewModel.handleAction($0) }
                )
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            if let items = section.items {
                if section.type == "horizontal" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                ComponentView(
                                    item,
                                    headStyles: headStyles,
                                    onHref: { viewModel.handleHref($0) },
                                    onAction: { viewModel.handleAction($0) }
                                )
                            }
                        }
                    }
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        ComponentView(
                            item,
                            headStyles: headStyles,
                            onHref: { viewModel.handleHref($0) },
                            onAction: { viewModel.handleAction($0) }
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func footerView(_ footer: JasonFooter, headStyles: [String: JasonStyle]) -> some View {
        if let tabs = footer.tabs, let items = tabs.items {
            // Tab bar footer
            HStack {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ComponentView(
                        item,
                        headStyles: headStyles,
                        onHref: { viewModel.handleHref($0) },
                        onAction: { viewModel.handleAction($0) }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(.background.shadow(.drop(radius: 1)))
        }
    }
}
