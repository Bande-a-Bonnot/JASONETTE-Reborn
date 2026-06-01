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
        _ = await execute(action, baseURL: documentURL, payload: nil)
    }

    @discardableResult
    private func execute(_ action: JasonAction, baseURL: URL?, payload: Any?) async -> Any? {
        do {
            let result = try await dispatch(action, baseURL: baseURL, payload: payload)
            let nextPayload = result ?? payload
            var chainedPayload = nextPayload
            for success in continuationActions(action.successActions, fallback: action.success) {
                chainedPayload = await execute(success, baseURL: baseURL, payload: chainedPayload) ?? chainedPayload
            }
            return chainedPayload
        } catch {
            var chainedPayload = payload
            for errorAction in continuationActions(action.errorActions, fallback: action.error) {
                chainedPayload = await execute(errorAction, baseURL: baseURL, payload: chainedPayload) ?? chainedPayload
            }
            return chainedPayload
        }
    }

    private func dispatch(_ action: JasonAction, baseURL: URL?, payload: Any?) async throws -> Any? {
        if let trigger = action.trigger {
            guard let namedAction = actionResolver?(trigger) else { return payload }
            return await execute(namedAction, baseURL: baseURL, payload: payloadFromOptions(action, fallback: payload)) ?? payload
        }

        guard let type = action.type else { return payload }
        let options = renderedOptions(for: action, payload: payload)

        switch type {
        // State
        case "$set":
            let context = actionContext(payload: payload)
            let values = options.mapValues { TemplateEngine.render($0.unwrapped, context: context) }
            stateManager.set(values)
            return values

        case "$get":
            return stateManager.local

        // Cache
        case "$cache.set":
            let values = options.compactMapValues { $0.value }
            stateManager.cacheSet(values)
            return values

        case "$cache.get":
            return stateManager.cache

        case "$cache.reset", "$flush":
            stateManager.cacheReset()
            return [:]

        // Render
        case "$render":
            if let data = options["data"]?.unwrapped {
                stateManager.set(["$jason": data])
            }
            let templateName = options["template"]?.string
            renderHandler?(templateName)
            return options["data"]?.unwrapped ?? payload

        case "$reload":
            reloadHandler?()
            return payload

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
            return payload

        case "$back":
            let href = JasonHref(url: nil, view: "$back")
            navigationHandler?(href)
            return payload

        case "$close":
            let href = JasonHref(url: nil, view: "$close")
            navigationHandler?(href)
            return payload

        // Network
        case "$network.request":
            return try await networkRequest(options, baseURL: baseURL)

        // Util
        case "$util.alert":
            let title = renderedString(options["title"], payload: payload) ?? ""
            let description = renderedString(options["description"], payload: payload)
            alertHandler?(title, description)
            return payload

        case "$util.toast":
            let text = renderedString(options["text"], payload: payload)
                ?? renderedString(options["title"], payload: payload)
                ?? "Done"
            alertHandler?(text, nil)
            return payload

        case "$util.banner":
            let title = renderedString(options["title"], payload: payload) ?? "Done"
            let description = renderedString(options["description"], payload: payload)
            alertHandler?(title, description)
            return payload

        case "$util.picker":
            let items = options["items"]?.array?.compactMap { item -> String? in
                guard let dictionary = item.dictionary else { return item.string }
                return dictionary["text"]?.string ?? dictionary["title"]?.string ?? dictionary["value"]?.string
            } ?? []
            alertHandler?("Picker", items.isEmpty ? "No picker items supplied." : items.joined(separator: "\n"))
            return payload

        case "$util.datepicker":
            let selected = Int(Date().timeIntervalSince1970)
            let value: [String: Any] = ["value": selected]
            stateManager.set(value)
            alertHandler?("Date", Date(timeIntervalSince1970: TimeInterval(selected)).formatted())
            return value

        // Media
        case "$audio.play":
            try playAudio(options, baseURL: baseURL)
            return payload

        case "$lambda":
            guard let name = options["name"]?.string,
                  let namedAction = actionResolver?(name) else { return payload }
            let lambdaPayload = options["options"].map { $0.unwrapped } ?? payload
            return await execute(namedAction, baseURL: baseURL, payload: lambdaPayload) ?? lambdaPayload

        case "$geo.get":
            let coordinate: [String: Any] = ["coord": "37.33233141,-122.0312186"]
            stateManager.set(coordinate)
            return coordinate

        case "$media.play", "$media.picker", "$media.camera", "$util.share", "$util.addressbook", "$vision.scan":
            alertHandler?("Not implemented yet", "\(type) is recognized, but this iOS renderer does not implement the native UI yet.")
            return payload

        case "$script.include":
            return payload

        case "$log", "$log.info", "$log.debug", "$log.error":
            print("[Jasonette] \(renderedString(options["text"], payload: payload) ?? String(describing: payload ?? ""))")
            return payload

        // Timer
        case "$timer.start":
            let tickActions = actionFromOption(options["action"]).map { [$0] }
                ?? continuationActions(action.successActions, fallback: action.success)
            startTimer(options, tickActions: tickActions, baseURL: baseURL, payload: payload)
            return payload

        case "$timer.stop":
            let name = options["name"]?.string ?? "default"
            timers[name]?.invalidate()
            timers[name] = nil
            return payload

        default:
            print("[Jasonette] Unknown action: \(type)")
            return payload
        }
    }

    private func renderedString(_ value: AnyCodable?, payload: Any?) -> String? {
        guard let value else { return nil }
        let rendered = TemplateEngine.render(value.unwrapped, context: actionContext(payload: payload))
        if let string = rendered as? String { return string }
        return "\(rendered)"
    }

    private func actionContext(payload: Any?) -> [String: Any] {
        var context = stateManager.local
        if let payload {
            context["$jason"] = payload
            if let dictionary = payload as? [String: Any] {
                context.merge(dictionary) { _, payloadValue in payloadValue }
            }
        } else if context["$jason"] == nil {
            context["$jason"] = stateManager.local
        }
        context["$get"] = stateManager.local
        context["$cache"] = stateManager.cache
        return context
    }

    private func renderedOptions(for action: JasonAction, payload: Any?) -> [String: AnyCodable] {
        let context = actionContext(payload: payload)
        if let options = action.options {
            return options.mapValues { wrapAsAnyCodable(TemplateEngine.render($0.unwrapped, context: context)) }
        }
        guard let rawOptions = action.rawOptions else { return [:] }
        return dictionaryFromAny(TemplateEngine.render(rawOptions.unwrapped, context: context)) ?? [:]
    }

    private func payloadFromOptions(_ action: JasonAction, fallback: Any?) -> Any? {
        let options = renderedOptions(for: action, payload: fallback)
        return options.isEmpty ? fallback : unwrapDictionary(options)
    }

    private func continuationActions(_ actions: [JasonAction]?, fallback: JasonAction?) -> [JasonAction] {
        if let actions, !actions.isEmpty { return actions }
        return fallback.map { [$0] } ?? []
    }

    private func actionFromOption(_ option: AnyCodable?) -> JasonAction? {
        guard let unwrapped = option?.unwrapped,
              JSONSerialization.isValidJSONObject(unwrapped),
              let data = try? JSONSerialization.data(withJSONObject: unwrapped) else {
            return nil
        }
        return try? JSONDecoder().decode(JasonAction.self, from: data)
    }

    private func dictionaryFromAny(_ value: Any) -> [String: AnyCodable]? {
        if let dictionary = value as? [String: AnyCodable] { return dictionary }
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues { wrapAsAnyCodable($0) }
        }
        return nil
    }

    private func unwrapDictionary(_ dictionary: [String: AnyCodable]) -> [String: Any] {
        dictionary.mapValues { $0.unwrapped }
    }

    private func wrapAsAnyCodable(_ value: Any) -> AnyCodable {
        switch value {
        case let codable as AnyCodable:
            return codable
        case let array as [Any]:
            return AnyCodable(array.map { wrapAsAnyCodable($0) })
        case let dictionary as [String: Any]:
            return AnyCodable(dictionary.mapValues { wrapAsAnyCodable($0) })
        default:
            return AnyCodable(value)
        }
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

    private func startTimer(_ options: [String: AnyCodable], tickActions: [JasonAction], baseURL: URL?, payload: Any?) {
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

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak self] _ in
            guard let self, !tickActions.isEmpty else { return }
            Task { @MainActor in
                guard !self.executingTimers.contains(name) else { return }
                self.executingTimers.insert(name)
                defer { self.executingTimers.remove(name) }
                var currentPayload = payload
                for action in tickActions {
                    currentPayload = await self.execute(action, baseURL: baseURL, payload: currentPayload) ?? currentPayload
                }
                if !repeats {
                    self.timers[name]?.invalidate()
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

    private func networkRequest(_ options: [String: AnyCodable], baseURL: URL?) async throws -> Any? {
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
            return json
        } else if let text = String(data: data, encoding: .utf8) {
            stateManager.set(["$response": text])
            return text
        }
        return nil
    }

    enum ActionError: Error {
        case invalidURL
        case blockedURL
        case httpError(Int)
    }
}
