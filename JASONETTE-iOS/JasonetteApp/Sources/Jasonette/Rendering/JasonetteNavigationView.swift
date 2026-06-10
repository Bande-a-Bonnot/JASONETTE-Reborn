import SwiftUI
#if os(iOS)
import SafariServices
#endif

/// Navigation stack/sheet target carrying Jasonette `$href.options` params.
struct NavigationTarget: Identifiable, Hashable {
    let id: String
    let url: URL
    let params: [String: AnyCodable]

    init(_ url: URL, params: [String: AnyCodable] = [:]) {
        self.id = [url.absoluteString, params.stableJSONString].joined(separator: "|")
        self.url = url
        self.params = params
    }
}

/// URL wrapper for item-driven Safari sheets — avoids global retroactive Identifiable on URL.
struct IdentifiableURL: Identifiable {
    let id: String
    let url: URL
    init(_ url: URL) { self.id = url.absoluteString; self.url = url }
}

private extension Dictionary where Key == String, Value == AnyCodable {
    var stableJSONString: String {
        let unwrapped = mapValues { $0.unwrapped }
        guard JSONSerialization.isValidJSONObject(unwrapped),
              let data = try? JSONSerialization.data(withJSONObject: unwrapped, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else { return String(describing: unwrapped.sorted { $0.key < $1.key }) }
        return string
    }
}

/// Navigation intent produced by a `JasonetteView`, consumed by its enclosing
/// `JasonetteNavigationView`. Handlers are scoped to one presentation — the
/// root container installs its own, each modal installs its own — so
/// navigation inside a modal cannot mutate the parent's stack.
enum NavigationRequest: Sendable {
    case push(URL, [String: AnyCodable] = [:])
    /// Request that the enclosing tab shell select the tab matching this URL.
    /// If no shell is present or no tab matches, falls through to `.push`.
    case switchTab(URL)
    case modal(URL, [String: AnyCodable] = [:])
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
    @State private var path: [NavigationTarget] = []
    @State private var modalTarget: NavigationTarget?
    @State private var safariURL: IdentifiableURL?
    @Environment(\.openURL) private var openURL
    @Environment(\.jasonetteSwitchTab) private var switchTab

    /// Provided by the parent when this container is itself presented as a
    /// sheet — used to dismiss the sheet on `$close`. `nil` at the root.
    private let onClose: (() -> Void)?

    // Scheme allowlists live on DocumentLoader to keep nav, action dispatch,
    // footer tabs, and $href in lockstep.

    private let initialParams: [String: AnyCodable]

    init(
        url: URL,
        preloadedDoc: JasonDocument? = nil,
        preloadedDocumentURL: URL? = nil,
        initialParams: [String: AnyCodable] = [:]
    ) {
        self.rootURL = url
        self.preloadedDoc = preloadedDoc
        self.preloadedDocumentURL = preloadedDocumentURL
        self.initialParams = initialParams
        self.onClose = nil
    }

    /// Sheet-scoped initializer used by the modal branch below.
    init(
        url: URL,
        preloadedDoc: JasonDocument? = nil,
        preloadedDocumentURL: URL? = nil,
        initialParams: [String: AnyCodable] = [:],
        onClose: @escaping () -> Void
    ) {
        self.rootURL = url
        self.preloadedDoc = preloadedDoc
        self.preloadedDocumentURL = preloadedDocumentURL
        self.initialParams = initialParams
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationDestination(for: NavigationTarget.self) { target in
                    JasonetteView(url: target.url, initialParams: target.params, onNavigate: dispatch)
                }
                .toolbar {
                    if onClose != nil {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { onClose?() }
                        }
                    }
                }
        }
        .sheet(item: $modalTarget) { target in
            JasonetteNavigationView(url: target.url, initialParams: target.params, onClose: { modalTarget = nil })
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
            JasonetteView(url: rootURL, preloadedDoc: doc, documentURL: preloadedDocumentURL, initialParams: initialParams, onNavigate: dispatch)
        } else {
            JasonetteView(url: rootURL, initialParams: initialParams, onNavigate: dispatch)
        }
    }

    private func dispatch(_ request: NavigationRequest) {
        switch request {
        case .back:
            if !path.isEmpty { path.removeLast() }

        case .close:
            // Close the currently-presented child modal if any; otherwise ask
            // our presenter to dismiss us (no-op at the root).
            if modalTarget != nil {
                modalTarget = nil
            } else {
                onClose?()
            }

        case .push(let url, let params):
            path.append(NavigationTarget(url, params: params))

        case .switchTab(let url):
            // Ask the enclosing tab shell. No shell or no match → push.
            if !switchTab(url) { path.append(NavigationTarget(url)) }

        case .modal(let url, let params):
            modalTarget = NavigationTarget(url, params: params)

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
