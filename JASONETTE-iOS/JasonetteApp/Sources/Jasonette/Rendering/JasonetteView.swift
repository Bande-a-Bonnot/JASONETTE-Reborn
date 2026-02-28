import SwiftUI

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
    }

    @ViewBuilder
    private var documentBody: some View {
        let root = viewModel.renderedRoot
        let head = root?.head
        let body = root?.body
        let headStyles = head?.styles ?? [:]

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header
                if let header = body?.header {
                    headerView(header, headStyles: headStyles)
                }

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
        .navigationTitle(head?.title ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func headerView(_ header: JasonHeader, headStyles: [String: JasonStyle]) -> some View {
        if let menu = header.menu {
            ComponentView(
                menu,
                headStyles: headStyles,
                onHref: { viewModel.handleHref($0) },
                onAction: { viewModel.handleAction($0) }
            )
            .padding(.horizontal)
        }
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
