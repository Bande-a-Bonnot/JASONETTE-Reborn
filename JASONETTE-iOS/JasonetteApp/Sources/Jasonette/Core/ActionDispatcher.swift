import Foundation

/// Executes Jasonette actions with success/error chaining.
@MainActor
public final class ActionDispatcher: ObservableObject {
    private let stateManager: StateManager
    private var navigationHandler: ((JasonHref) -> Void)?
    private var reloadHandler: (() -> Void)?
    private var alertHandler: ((String, String?) -> Void)?
    private var timers: [String: Timer] = [:]

    private static let maxTimers = 50
    private static let minTimerInterval: TimeInterval = 0.1

    public init(stateManager: StateManager) {
        self.stateManager = stateManager
    }

    public func setNavigationHandler(_ handler: @escaping (JasonHref) -> Void) {
        self.navigationHandler = handler
    }

    public func setReloadHandler(_ handler: @escaping () -> Void) {
        self.reloadHandler = handler
    }

    public func setAlertHandler(_ handler: @escaping (String, String?) -> Void) {
        self.alertHandler = handler
    }

    /// Invalidate all active timers. Call from view's onDisappear.
    public func invalidateAllTimers() {
        for timer in timers.values { timer.invalidate() }
        timers.removeAll()
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
            break

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
            let title = options["title"]?.string ?? ""
            let description = options["description"]?.string
            alertHandler?(title, description)

        case "$util.toast", "$util.banner":
            break

        // Timer
        case "$timer.start":
            startTimer(options, successAction: action.success)

        case "$timer.stop":
            let name = options["name"]?.string ?? "default"
            timers[name]?.invalidate()
            timers[name] = nil

        default:
            print("[Jasonette] Unknown action: \(type)")
        }
    }

    // MARK: - Timer

    private func startTimer(_ options: [String: AnyCodable], successAction: JasonAction?) {
        let name = options["name"]?.string ?? "default"
        let interval = max(options["interval"]?.double ?? 1.0, Self.minTimerInterval)
        let repeats = options["repeats"]?.bool ?? true

        // Enforce timer limit
        timers[name]?.invalidate()
        guard timers.count < Self.maxTimers else {
            print("[Jasonette] Timer limit reached (\(Self.maxTimers))")
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak self] _ in
            guard let self, let successAction else { return }
            Task { @MainActor in
                await self.execute(successAction)
            }
        }
        timers[name] = timer
    }

    // MARK: - Network

    private static let allowedSchemes: Set<String> = ["https", "http"]

    private static let blockedHeaders: Set<String> = [
        "host", "cookie", "authorization", "proxy-authorization",
        "set-cookie", "transfer-encoding", "content-length"
    ]

    private func networkRequest(_ options: [String: AnyCodable]) async throws {
        guard let urlStr = options["url"]?.string,
              let url = URL(string: urlStr) else {
            throw ActionError.invalidURL
        }

        guard let scheme = url.scheme?.lowercased(),
              Self.allowedSchemes.contains(scheme) else {
            throw ActionError.blockedURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = options["method"]?.string?.uppercased() ?? "GET"

        if let headers = options["headers"]?.dictionary {
            for (key, value) in headers {
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
