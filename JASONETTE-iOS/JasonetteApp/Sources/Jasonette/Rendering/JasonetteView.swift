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
struct JasonetteView: View {
    @StateObject private var viewModel: JasonetteViewModel
    @Environment(\.jasonetteIsInsideTabShell) private var isInsideTabShell
    @Environment(\.jasonetteCurrentTabID) private var currentTabID
    @Environment(\.jasonetteRegisterTabActionHandler) private var registerTabActionHandler

    init(url: URL, onNavigate: ((NavigationRequest) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: JasonetteViewModel(url: url, onNavigate: onNavigate))
    }

    init(document: JasonDocument, onNavigate: ((NavigationRequest) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: JasonetteViewModel(document: document, onNavigate: onNavigate))
    }

    /// Seeded init: render `preloadedDoc` on first load, refetch from `url`
    /// on subsequent reloads. Used by the tab shell to avoid a duplicate
    /// fetch of the bootstrap document while preserving reload semantics.
    init(url: URL, preloadedDoc: JasonDocument, documentURL: URL? = nil, onNavigate: ((NavigationRequest) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: JasonetteViewModel(url: url, preloadedDoc: preloadedDoc, documentURL: documentURL, onNavigate: onNavigate))
    }

    var body: some View {
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
        .onAppear { registerForTabActionsIfNeeded() }
    }

    private func registerForTabActionsIfNeeded() {
        guard let currentTabID else { return }
        let viewModel = viewModel
        registerTabActionHandler(currentTabID) { [weak viewModel] action in
            viewModel?.handleAction(action)
        }
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
        .ifLet(body?.background?.string.flatMap { Color(css: $0) }) { view, color in
            view.background(color.ignoresSafeArea())
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
                onAction: { viewModel.handleAction($0) },
                documentURL: viewModel.documentURL
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

    private func resolveLayerStyle(_ component: JasonComponent, headStyles: [String: JasonStyle]) -> JasonStyle {
        JasonStyle.resolve(for: component, headStyles: headStyles)
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
                    onAction: { viewModel.handleAction($0) },
                    documentURL: viewModel.documentURL
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
                                    onAction: { viewModel.handleAction($0) },
                                    documentURL: viewModel.documentURL
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
                            onAction: { viewModel.handleAction($0) },
                            documentURL: viewModel.documentURL
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
        // The tab bar is an app-shell concern: if we're rendered inside a
        // JasonetteTabShell, the shell already draws the persistent bar and
        // any footer.tabs declared on pushed/secondary docs must be ignored.
        if let tabs = footer.tabs, let items = tabs.items, !isInsideTabShell {
            // Tab bar footer — tabs take precedence over input.
            // spacing: 0 so per-item backgrounds/shadows align edge-to-edge.
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Group {
                        if item.type == nil {
                            FooterTabItemView(
                                item: item,
                                headStyles: headStyles,
                                onHref: { viewModel.handleHref($0) },
                                onAction: { viewModel.handleAction($0) },
                                documentURL: viewModel.documentURL
                            )
                        } else {
                            ComponentView(
                                item,
                                headStyles: headStyles,
                                onHref: { viewModel.handleHref($0) },
                                onAction: { viewModel.handleAction($0) },
                                documentURL: viewModel.documentURL
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(.background.shadow(.drop(radius: 1)))
        } else if let input = footer.input {
            // Input bar footer
            FooterInputView(
                input: input,
                onAction: { viewModel.handleAction($0) },
                documentURL: viewModel.documentURL
            )
        }
    }
}

// MARK: - Footer Input View

/// Renders `footer.input` as a text input bar at the bottom of the screen.
///
/// This is a structural element with fixed semantics — left button, text field,
/// right button — not a generic component dispatch.
@MainActor
struct FooterInputView: View {
    let input: JasonFooterInput
    let onAction: ((JasonAction) -> Void)?
    let documentURL: URL?

    @EnvironmentObject private var stateManager: StateManager

    var body: some View {
        HStack(spacing: 8) {
            // Optional left button (e.g. camera icon)
            if let left = input.left {
                footerButton(for: left)
            }

            // Text field bound to StateManager
            let name = input.name ?? ""
            let placeholder = input.placeholder ?? ""
            // Only bind to state if name is non-empty
            if name.isEmpty {
                TextField(placeholder, text: .constant(""))
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder, text: stateManager.binding(forKey: name, default: ""))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier(name)
            }

            // Optional right button (e.g. Send)
            if let right = input.right {
                footerButton(for: right)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.background.shadow(.drop(radius: 1)))
    }

    @ViewBuilder
    private func footerButton(for component: JasonComponent) -> some View {
        let buttonContent = Group {
            if let url = resolvedImageURL(for: component) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Color.clear
                    }
                }
                .frame(width: 24, height: 24)
            } else if let text = component.text {
                Text(text)
                    .fontWeight(.medium)
            }
        }

        if let action = component.action {
            Button { onAction?(action) } label: { buttonContent }
                .buttonStyle(.plain)
        } else {
            buttonContent
        }
    }

    func resolvedImageURL(for component: JasonComponent) -> URL? {
        component.imageURL.flatMap { JasonURL.resolve($0, against: documentURL) }
    }
}

// MARK: - Footer Tab Item View

/// Renders a `footer.tabs.items` entry that has no `type` field.
///
/// Tab items use an implicit shape: `image`, `text`, optional `badge`, and `url`
/// (which navigates when tapped). Routing these through `ComponentView` yields
/// `[Unknown: nil]` because there is no component type — so they get their own
/// structural view, like `FooterInputView`.
@MainActor
struct FooterTabItemView: View {
    let item: JasonComponent
    let headStyles: [String: JasonStyle]
    let onHref: ((JasonHref) -> Void)?
    let onAction: ((JasonAction) -> Void)?
    let documentURL: URL?

    var body: some View {
        // Icon size resolves class-defined styles (via headStyles) merged with
        // inline style — matching how JasonStyleModifier resolves every other
        // style property. Using item.style alone would ignore `class: "tab_icon"`.
        let resolved = resolvedStyle()
        let iconWidth = resolved.width?.cgFloat ?? resolved.height?.cgFloat ?? 24
        let iconHeight = resolved.height?.cgFloat ?? resolved.width?.cgFloat ?? 24
        // Strip width/height from the style applied to the cell; they size the
        // icon (above) — applying them to the VStack cell would cap its frame.
        let cellStyle = resolved.withoutSize()
        let content = VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                if let url = resolvedIconURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: iconWidth, height: iconHeight)
                }
                if let badge = item.badge, !badge.isEmpty {
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.red))
                        .offset(x: 6, y: -4)
                }
            }
            if let text = item.text, !text.isEmpty {
                Text(text).font(.caption)
            }
        }
        .contentShape(Rectangle())
        // Apply the resolved style to the cell WITHOUT width/height: those
        // dimensions are icon-specific in the tab-item shape (real Jasonpedia
        // fixtures set `"height": "21"` to size the icon) and clobbering the
        // cell's height clips the caption. headStyles/className are already
        // folded into `cellStyle`, so pass nil to avoid double-resolution.
        .modifier(JasonStyleModifier(style: cellStyle, headStyles: [:], className: nil))

        // Navigation priority mirrors ComponentView (href > action). The
        // typeless tab-item shape also accepts a shorthand `url` on the item;
        // when `href` is absent we synthesize a `JasonHref` from `url` in a
        // dedicated else-if branch so url-only fixtures still navigate. When
        // both are present, `href` wins and its missing `.url` is populated
        // from the shorthand.
        if let href = item.href {
            Button {
                var h = href
                if h.url == nil, let urlString = item.url, !urlString.isEmpty {
                    h.url = urlString
                }
                if !resolvesToCurrentDocument(h) {
                    onHref?(h)
                }
            } label: { content }
                .buttonStyle(.plain)
        } else if let urlString = item.url, !urlString.isEmpty {
            Button {
                var href = JasonHref()
                href.url = urlString
                if !resolvesToCurrentDocument(href) {
                    onHref?(href)
                }
            } label: { content }
                .buttonStyle(.plain)
        } else if let action = item.action {
            Button { onAction?(action) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    var resolvedIconURL: URL? {
        item.image.flatMap { JasonURL.resolve($0, against: documentURL) }
    }

    func resolvesToCurrentDocument(_ href: JasonHref) -> Bool {
        guard let documentURL,
              let urlString = href.url,
              let targetURL = JasonURL.resolve(urlString, against: documentURL) else { return false }
        return targetURL.standardized == documentURL.standardized
    }

    private func resolvedStyle() -> JasonStyle {
        JasonStyle.resolve(for: item, headStyles: headStyles)
    }
}
