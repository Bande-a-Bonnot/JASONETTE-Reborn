import SwiftUI

/// Public entry point for a Jasonette app. Fetches the entry document, then
/// renders either a single `JasonetteNavigationView` (no tabs) or a
/// `JasonetteTabShell` (tabs declared in `body.footer.tabs`). Promotion
/// happens exactly once, at bootstrap, and never reverses.
///
/// This replaces direct use of `JasonetteNavigationView` as the app's root —
/// the nav view now owns just one navigable scope; the shell owns tabs.
@MainActor
public struct JasonetteRootView: View {
    @StateObject private var coordinator: JasonetteNavigationCoordinator
    @State private var bootstrap: BootstrapState = .loading

    private enum BootstrapState {
        case loading
        case ready
        case error(String)
    }

    private let loader = DocumentLoader()

    public init(url: URL) {
        _coordinator = StateObject(wrappedValue: JasonetteNavigationCoordinator(entryURL: url))
    }

    public var body: some View {
        Group {
            switch (bootstrap, coordinator.mode) {
            case (.loading, _):
                ProgressView().task { await runBootstrap() }

            case (.error(let message), _):
                VStack(spacing: 12) {
                    Text("Failed to load")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    Button("Retry") {
                        bootstrap = .loading
                    }
                }

            case (.ready, .single(let rootURL, let preloadedDoc, let preloadedDocumentURL)):
                JasonetteNavigationView(
                    url: rootURL,
                    preloadedDoc: preloadedDoc,
                    preloadedDocumentURL: preloadedDocumentURL
                )

            case (.ready, .tabs(let shell, let bootstrapDoc, let bootstrapURL)):
                JasonetteTabShell(
                    shell: shell,
                    bootstrapDoc: bootstrapDoc,
                    bootstrapURL: bootstrapURL,
                    bootstrapDocumentURL: coordinator.bootstrapDocumentURL
                )
            }
        }
    }

    private func runBootstrap() async {
        do {
            let loaded = try await loader.loadWithMetadata(from: coordinator.entryURL)
            coordinator.bootstrapDidLoad(doc: loaded.document, documentURL: loaded.url)
            bootstrap = .ready
        } catch is CancellationError {
            return
        } catch {
            bootstrap = .error(error.localizedDescription)
        }
    }
}
