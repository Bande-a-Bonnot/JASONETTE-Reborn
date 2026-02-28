import Foundation

/// Executes Jasonette actions with success/error chaining.
@MainActor
public final class ActionDispatcher: ObservableObject {
    private let stateManager: StateManager
    private var navigationHandler: ((JasonHref) -> Void)?
    private var reloadHandler: (() -> Void)?

    public init(stateManager: StateManager) {
        self.stateManager = stateManager
    }

    public func setNavigationHandler(_ handler: @escaping (JasonHref) -> Void) {
        self.navigationHandler = handler
    }

    public func setReloadHandler(_ handler: @escaping () -> Void) {
        self.reloadHandler = handler
    }

    public func execute(_ action: JasonAction) async {
        do {
            try await dispatch(action)
            if let success = action.success {
                await execute(success)
            }
        } catch {
            if let errorAction = action.error {
                await execute(errorAction)
            }
        }
    }

    private func dispatch(_ action: JasonAction) async throws {
        guard let type = action.type else { return }
        let options = action.options ?? [:]

        switch type {
        // State
        case "$set":
            let values = options.compactMapValues { $0.value }
            stateManager.set(values)

        case "$get":
            break // state is always available via stateManager.local

        // Cache
        case "$cache.set":
            let values = options.compactMapValues { $0.value }
            stateManager.cacheSet(values)

        case "$cache.get":
            break

        case "$cache.reset":
            stateManager.cacheReset()

        // Render
        case "$render":
            // Triggers a re-render. The view hierarchy observes stateManager.
            stateManager.objectWillChange.send()

        case "$reload":
            reloadHandler?()

        // Navigation
        case "$href":
            if let url = options["url"]?.string {
                let href = JasonHref(
                    url: url,
                    view: options["view"]?.string,
                    transition: options["transition"]?.string,
                    fresh: options["fresh"]?.bool
                )
                navigationHandler?(href)
            }

        case "$back":
            let href = JasonHref(url: nil, view: "$back")
            navigationHandler?(href)

        case "$close":
            let href = JasonHref(url: nil, view: "$close")
            navigationHandler?(href)

        // Network
        case "$network.request":
            try await networkRequest(options)

        // Util
        case "$util.alert":
            // Alert handled at view level via Published state
            break

        case "$util.toast", "$util.banner":
            // Toast/banner handled at view level
            break

        default:
            print("[Jasonette] Unknown action: \(type)")
        }
    }

    // MARK: - Network

    /// Allowed URL schemes for network requests.
    private static let allowedSchemes: Set<String> = ["https", "http"]

    /// Headers that must not be set by Jasonette documents.
    private static let blockedHeaders: Set<String> = [
        "host", "cookie", "authorization", "proxy-authorization",
        "set-cookie", "transfer-encoding", "content-length"
    ]

    private func networkRequest(_ options: [String: AnyCodable]) async throws {
        guard let urlStr = options["url"]?.string,
              let url = URL(string: urlStr) else {
            throw ActionError.invalidURL
        }

        // Validate URL scheme to prevent file:// and other unsafe protocols
        guard let scheme = url.scheme?.lowercased(),
              Self.allowedSchemes.contains(scheme) else {
            throw ActionError.blockedURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = options["method"]?.string?.uppercased() ?? "GET"

        if let headers = options["headers"]?.dictionary {
            for (key, value) in headers {
                // Block sensitive headers to prevent injection attacks
                guard !Self.blockedHeaders.contains(key.lowercased()) else { continue }
                if let str = value.string {
                    request.setValue(str, forHTTPHeaderField: key)
                }
            }
        }

        if let body = options["body"] {
            if let data = try? JSONSerialization.data(withJSONObject: body.value as Any) {
                request.httpBody = data
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw ActionError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Store response in local state
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            stateManager.set(json)
        }
    }

    enum ActionError: Error {
        case invalidURL
        case blockedURL
        case httpError(Int)
    }
}
