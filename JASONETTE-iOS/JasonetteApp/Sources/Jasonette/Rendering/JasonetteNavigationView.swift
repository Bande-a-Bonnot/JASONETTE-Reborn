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

/// Navigation container that handles $href push/modal/web/app navigation.
@MainActor
public struct JasonetteNavigationView: View {
    let rootURL: URL

    @State private var path: [URL] = []
    @State private var modalURL: IdentifiableURL?
    @State private var safariURL: IdentifiableURL?
    @Environment(\.openURL) private var openURL

    /// Schemes allowed for in-app web views.
    private static let webSchemes: Set<String> = ["https", "http"]
    /// Schemes allowed for system URL opening (mailto, tel, etc.).
    private static let appSchemes: Set<String> = ["https", "http", "mailto", "tel", "sms"]

    public init(url: URL) {
        self.rootURL = url
    }

    public var body: some View {
        NavigationStack(path: $path) {
            JasonetteView(url: rootURL)
                .navigationDestination(for: URL.self) { url in
                    JasonetteView(url: url)
                }
        }
        .sheet(item: $modalURL) { item in
            NavigationStack {
                JasonetteView(url: item.url)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { modalURL = nil }
                        }
                    }
            }
        }
        #if os(iOS)
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .jasonetteNavigate)) { notification in
            handleNavigation(notification)
        }
    }

    private func handleNavigation(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        // Handle $back
        if let back = userInfo["back"] as? Bool, back {
            if !path.isEmpty {
                path.removeLast()
            }
            return
        }

        // Handle $close
        if let close = userInfo["close"] as? Bool, close {
            modalURL = nil
            return
        }

        guard let href = userInfo["href"] as? JasonHref,
              let url = userInfo["url"] as? URL else { return }

        switch href.view {
        case "web":
            guard let scheme = url.scheme?.lowercased(),
                  Self.webSchemes.contains(scheme) else { return }
            #if os(iOS)
            safariURL = IdentifiableURL(url)
            #else
            openURL(url)
            #endif

        case "app":
            guard let scheme = url.scheme?.lowercased(),
                  Self.appSchemes.contains(scheme) else { return }
            openURL(url)

        default:
            if href.transition == "modal" {
                modalURL = IdentifiableURL(url)
            } else {
                path.append(url)
            }
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
