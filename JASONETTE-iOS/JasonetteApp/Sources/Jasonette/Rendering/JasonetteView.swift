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

        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Sections
                    if let sections = body?.sections {
                        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                            sectionView(section, headStyles: headStyles)
                        }
                    }

                    // Layers
                    if let layers = body?.layers {
                        ForEach(Array(layers.enumerated()), id: \.offset) { _, component in
                            ComponentView(
                                component,
                                headStyles: headStyles,
                                onHref: { viewModel.handleHref($0) },
                                onAction: { viewModel.handleAction($0) }
                            )
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
            // Tab bar footer — tabs take precedence over input
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
        } else if let input = footer.input {
            // Input bar footer
            FooterInputView(
                input: input,
                onAction: { viewModel.handleAction($0) }
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
            if let imageURL = component.imageURL, let url = URL(string: imageURL) {
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
}
