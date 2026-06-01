import AVFoundation
import Foundation

/// Executes Jasonette actions with success/error chaining.
@MainActor
public final class ActionDispatcher: ObservableObject {
    private let stateManager: StateManager
    private var navigationHandler: ((JasonHref) -> Void)?
    private var reloadHandler: (() -> Void)?
    private var alertHandler: ((String, String?) -> Void)?
    private var renderHandler: ((String?) -> Void)?
    private var actionResolver: ((String) -> JasonAction?)?
    private var audioPlayHandler: ((URL) -> Void)?
    private var audioPlayer: AVPlayer?
    private var timers: [String: Timer] = [:]
    private var executingTimers: Set<String> = []

    private static let maxTimers = 50
    private static let minTimerInterval: TimeInterval = 0.1

    private let session: URLSession
    private var documentURL: URL?

    public init(stateManager: StateManager, session: URLSession = .shared, documentURL: URL? = nil) {
        self.session = session
        self.stateManager = stateManager
        self.documentURL = documentURL
    }

    public func setDocumentURL(_ url: URL?) {
        documentURL = url
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

    public func setRenderHandler(_ handler: @escaping (String?) -> Void) {
        self.renderHandler = handler
    }

    public func setActionResolver(_ handler: @escaping (String) -> JasonAction?) {
        self.actionResolver = handler
    }

    func setAudioPlayHandler(_ handler: @escaping (URL) -> Void) {
        self.audioPlayHandler = handler
    }

    /// Invalidate all active timers. Call from view's onDisappear.
    public func invalidateAllTimers() {
        for timer in timers.values { timer.invalidate() }
        timers.removeAll()
        audioPlayer?.pause()
        audioPlayer = nil
    }

    public func execute(_ action: JasonAction) async {
        await execute(action, baseURL: documentURL)
    }

    private func execute(_ action: JasonAction, baseURL: URL?) async {
        do {
            try await dispatch(action, baseURL: baseURL)
            if let success = action.success {
                await execute(success, baseURL: baseURL)
            }
        } catch {
            if let errorAction = action.error {
                await execute(errorAction, baseURL: baseURL)
            }
        }
    }

    private func dispatch(_ action: JasonAction, baseURL: URL?) async throws {
        if let trigger = action.trigger {
            guard let namedAction = actionResolver?(trigger) else { return }
            await execute(namedAction, baseURL: baseURL)
            return
        }

        guard let type = action.type else { return }
        let options = action.options ?? [:]

        switch type {
        // State
        case "$set":
            let context = actionContext()
            let values = options.mapValues { TemplateEngine.render($0.unwrapped, context: context) }
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
            let templateName = options["template"]?.string
            renderHandler?(templateName)

        case "$reload":
            reloadHandler?()

        // Navigation
        case "$href":
            if let url = options["url"]?.string {
                let resolvedURL = JasonURL.resolve(url, against: baseURL)?.absoluteString ?? url
                let href = JasonHref(
                    url: resolvedURL,
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
            try await networkRequest(options, baseURL: baseURL)

        // Util
        case "$util.alert":
            let title = renderedString(options["title"]) ?? ""
            let description = renderedString(options["description"])
            alertHandler?(title, description)

        case "$util.toast", "$util.banner":
            break

        // Media
        case "$audio.play":
            try playAudio(options, baseURL: baseURL)

        // Timer
        case "$timer.start":
            startTimer(options, successAction: action.success, baseURL: baseURL)

        case "$timer.stop":
            let name = options["name"]?.string ?? "default"
            timers[name]?.invalidate()
            timers[name] = nil

        default:
            print("[Jasonette] Unknown action: \(type)")
        }
    }

    private func renderedString(_ value: AnyCodable?) -> String? {
        guard let string = value?.string else { return nil }
        return TemplateEngine.render(string, context: actionContext()) as? String ?? string
    }

    private func actionContext() -> [String: Any] {
        var context = stateManager.local
        context["$get"] = stateManager.local
        context["$cache"] = stateManager.cache
        return context
    }

    // MARK: - Audio

    private func playAudio(_ options: [String: AnyCodable], baseURL: URL?) throws {
        guard let urlStr = options["url"]?.string,
              let url = JasonURL.resolve(urlStr, against: baseURL) else {
            throw ActionError.invalidURL
        }
        guard let scheme = url.scheme?.lowercased(),
              DocumentLoader.allowedSchemes.contains(scheme) else {
            throw ActionError.blockedURL
        }

        if let audioPlayHandler {
            audioPlayHandler(url)
            return
        }
        #if os(iOS) || os(tvOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        audioPlayer = AVPlayer(url: url)
        audioPlayer?.play()
    }

    // MARK: - Timer

    private func startTimer(_ options: [String: AnyCodable], successAction: JasonAction?, baseURL: URL?) {
        let name = options["name"]?.string ?? "default"
        let interval = max(options["interval"]?.double ?? 1.0, Self.minTimerInterval)
        let repeats = options["repeats"]?.bool ?? true

        // Invalidate and remove existing timer before checking limit
        timers[name]?.invalidate()
        timers[name] = nil
        guard timers.count < Self.maxTimers else {
            print("[Jasonette] Timer limit reached (\(Self.maxTimers))")
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak self] timer in
            guard let self, let successAction else { return }
            Task { @MainActor in
                guard !self.executingTimers.contains(name) else { return }
                self.executingTimers.insert(name)
                defer { self.executingTimers.remove(name) }
                await self.execute(successAction, baseURL: baseURL)
                if !repeats {
                    self.timers[name] = nil
                }
            }
        }
        timers[name] = timer
    }

    // MARK: - Network

    private static let blockedHeaders: Set<String> = [
        "host", "cookie", "authorization", "proxy-authorization",
        "set-cookie", "transfer-encoding", "content-length"
    ]

    private func networkRequest(_ options: [String: AnyCodable], baseURL: URL?) async throws {
        guard let urlStr = options["url"]?.string,
              let url = JasonURL.resolve(urlStr, against: baseURL) else {
            throw ActionError.invalidURL
        }

        guard let scheme = url.scheme?.lowercased(),
              DocumentLoader.allowedSchemes.contains(scheme) else {
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
            let unwrappedBody = body.unwrapped
            if JSONSerialization.isValidJSONObject(unwrappedBody),
               let data = try? JSONSerialization.data(withJSONObject: unwrappedBody) {
                request.httpBody = data
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw ActionError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        if let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            stateManager.set(["$response": json])
        } else if let text = String(data: data, encoding: .utf8) {
            stateManager.set(["$response": text])
        }
    }

    enum ActionError: Error {
        case invalidURL
        case blockedURL
        case httpError(Int)
    }
}
