import SwiftUI
#if os(iOS)
import SafariServices
#endif

/// Navigation container that handles $href push/modal/web/app navigation.
@MainActor
public struct JasonetteNavigationView: View {
    let rootURL: URL

    @State private var path: [URL] = []
    @State private var modalURL: URL?
    @State private var safariURL: URL?
    @Environment(\.openURL) private var openURL

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
        .sheet(item: $modalURL) { url in
            NavigationStack {
                JasonetteView(url: url)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { modalURL = nil }
                        }
                    }
            }
        }
        #if os(iOS)
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
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
            // Open in Safari sheet (iOS) or external browser (other platforms)
            #if os(iOS)
            safariURL = url
            #else
            openURL(url)
            #endif

        case "app":
            // Open with system handler (mailto:, tel:, sms:, etc.)
            openURL(url)

        default:
            // Default or "jason" view
            if href.transition == "modal" {
                modalURL = url
            } else {
                path.append(url)
            }
        }
    }
}

// MARK: - URL Identifiable conformance for sheet(item:)

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
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
