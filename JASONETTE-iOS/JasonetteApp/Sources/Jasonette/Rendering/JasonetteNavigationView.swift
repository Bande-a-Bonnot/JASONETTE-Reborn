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
enum NavigationRequest: Sendable {
    case push(URL)
    /// Request that the enclosing tab shell select the tab matching this URL.
    /// If no shell is present or no tab matches, falls through to `.push`.
    case switchTab(URL)
    case modal(URL)
    case back
    case close
    case web(URL)
    case app(URL)
}

/// One navigable Jasonette scope: a NavigationStack + its own modal slot.
/// Knows nothing about tabs. A tab shell mounts N of these, one per tab,
/// and flips visibility — but that is the shell's concern. The nav view
/// just runs its own stack and asks the shell (via env) to switch tabs
/// when a `.switchTab` request arrives.
///
/// App authors should use `JasonetteRootView(url:)` as the app entry
/// point — that's the view that promotes to the tab shell when the
/// bootstrap document declares `body.footer.tabs`. Mounting
/// `JasonetteNavigationView` directly is supported but keeps you in
/// single-stack mode: `footer.tabs` is rendered in-page by `JasonetteView`
/// rather than as a persistent shell bar, and `transition:"switch"` hrefs
/// can only fall back to `.push` since there is no enclosing shell.
@MainActor
struct JasonetteNavigationView: View {
    let rootURL: URL
    let preloadedDoc: JasonDocument?
    let preloadedDocumentURL: URL?
    @State private var path: [URL] = []
    @State private var modalURL: IdentifiableURL?
    @State private var safariURL: IdentifiableURL?
    @Environment(\.openURL) private var openURL
    @Environment(\.jasonetteSwitchTab) private var switchTab

    /// Provided by the parent when this container is itself presented as a
    /// sheet — used to dismiss the sheet on `$close`. `nil` at the root.
    private let onClose: (() -> Void)?

    // Scheme allowlists live on DocumentLoader to keep nav, action dispatch,
    // footer tabs, and $href in lockstep.

    init(url: URL, preloadedDoc: JasonDocument? = nil, preloadedDocumentURL: URL? = nil) {
        self.rootURL = url
        self.preloadedDoc = preloadedDoc
        self.preloadedDocumentURL = preloadedDocumentURL
        self.onClose = nil
    }

    /// Sheet-scoped initializer used by the modal branch below.
    init(url: URL, preloadedDoc: JasonDocument? = nil, preloadedDocumentURL: URL? = nil, onClose: @escaping () -> Void) {
        self.rootURL = url
        self.preloadedDoc = preloadedDoc
        self.preloadedDocumentURL = preloadedDocumentURL
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
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

    @ViewBuilder
    private var rootContent: some View {
        if let doc = preloadedDoc {
            JasonetteView(url: rootURL, preloadedDoc: doc, documentURL: preloadedDocumentURL, onNavigate: dispatch)
        } else {
            JasonetteView(url: rootURL, onNavigate: dispatch)
        }
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

        case .switchTab(let url):
            // Ask the enclosing tab shell. No shell or no match → push.
            if !switchTab(url) { path.append(url) }

        case .modal(let url):
            modalURL = IdentifiableURL(url)

        case .web(let url):
            guard let scheme = url.scheme?.lowercased(),
                  DocumentLoader.allowedSchemes.contains(scheme) else { return }
            #if os(iOS)
            safariURL = IdentifiableURL(url)
            #else
            openURL(url)
            #endif

        case .app(let url):
            guard let scheme = url.scheme?.lowercased(),
                  DocumentLoader.appSchemes.contains(scheme) else { return }
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
