import SwiftUI
#if os(iOS)
import SafariServices
#endif

/// URL wrapper for item-driven .sheet(item:) — avoids global retroactive Identifiable on URL.
struct IdentifiableURL: Identifiable {
    let id: String
    let url: URL
    init(_ url: URL) { self.id = url.absoluteString; self.url = url }
}

/// Navigation intent produced by a `JasonetteView`, consumed by its enclosing
/// `JasonetteNavigationView`. Handlers are scoped to one presentation — the
/// root container installs its own, each modal installs its own — so
/// navigation inside a modal cannot mutate the parent's stack.
public enum NavigationRequest: Sendable {
    case push(URL)
    case switchRoot(URL)
    case modal(URL)
    case back
    case close
    case web(URL)
    case app(URL)
}

/// Navigation container. Owns a `NavigationStack`, its path, and one optional
/// child modal presentation. Installs a scoped dispatch closure into every
/// `JasonetteView` it creates so all href / action navigation events in this
/// subtree mutate only this container's state.
@MainActor
public struct JasonetteNavigationView: View {
    @State private var currentRoot: URL
    @State private var path: [URL] = []
    @State private var modalURL: IdentifiableURL?
    @State private var safariURL: IdentifiableURL?
    @Environment(\.openURL) private var openURL

    /// Provided by the parent when this container is itself presented as a
    /// sheet — used to dismiss the sheet on `$close`. `nil` at the root.
    private let onClose: (() -> Void)?

    private static let webSchemes: Set<String> = ["https", "http"]
    private static let appSchemes: Set<String> = ["https", "http", "mailto", "tel", "sms"]

    public init(url: URL) {
        self._currentRoot = State(initialValue: url)
        self.onClose = nil
    }

    /// Sheet-scoped initializer used by the modal branch below.
    init(url: URL, onClose: @escaping () -> Void) {
        self._currentRoot = State(initialValue: url)
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack(path: $path) {
            JasonetteView(url: currentRoot, onNavigate: dispatch)
                .id(currentRoot)
                .navigationDestination(for: URL.self) { url in
                    JasonetteView(url: url, onNavigate: dispatch)
                }
                .toolbar {
                    if onClose != nil {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { onClose?() }
                        }
                    }
                }
        }
        .sheet(item: $modalURL) { item in
            JasonetteNavigationView(url: item.url, onClose: { modalURL = nil })
        }
        #if os(iOS)
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        #endif
    }

    private func dispatch(_ request: NavigationRequest) {
        switch request {
        case .back:
            if !path.isEmpty { path.removeLast() }

        case .close:
            // Close the currently-presented child modal if any; otherwise ask
            // our presenter to dismiss us (no-op at the root).
            if modalURL != nil {
                modalURL = nil
            } else {
                onClose?()
            }

        case .push(let url):
            path.append(url)

        case .switchRoot(let url):
            // Tab-bar semantics: replace the stack root and clear history.
            path = []
            currentRoot = url

        case .modal(let url):
            modalURL = IdentifiableURL(url)

        case .web(let url):
            guard let scheme = url.scheme?.lowercased(),
                  Self.webSchemes.contains(scheme) else { return }
            #if os(iOS)
            safariURL = IdentifiableURL(url)
            #else
            openURL(url)
            #endif

        case .app(let url):
            guard let scheme = url.scheme?.lowercased(),
                  Self.appSchemes.contains(scheme) else { return }
            openURL(url)
        }
    }
}

// MARK: - Safari wrapper

#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
#endif
