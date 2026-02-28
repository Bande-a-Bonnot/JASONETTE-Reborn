import SwiftUI

/// Navigation container that handles $href push/modal navigation.
@MainActor
public struct JasonetteNavigationView: View {
    let rootURL: URL

    @State private var path: [URL] = []

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
        .onReceive(NotificationCenter.default.publisher(for: .jasonetteNavigate)) { notification in
            guard let userInfo = notification.userInfo,
                  let url = userInfo["url"] as? URL else { return }
            path.append(url)
        }
    }
}
