import AVFoundation
import CoreLocation
import Foundation

@MainActor
protocol GeolocationProviding: AnyObject {
    func currentCoordinate() async throws -> String
}

@MainActor
private final class CoreLocationGeolocationProvider: NSObject, GeolocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<String, Error>?
    #if os(iOS) || os(tvOS) || os(visionOS)
    private var serviceSession: CLServiceSession?
    #endif

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentCoordinate() async throws -> String {
        guard CLLocationManager.locationServicesEnabled() else {
            throw ActionDispatcher.ActionError.locationUnavailable
        }
        guard continuation == nil else {
            throw ActionDispatcher.ActionError.locationRequestInProgress
        }

        let usingServiceSession = startWhenInUseServiceSessionIfAvailable()
        switch manager.authorizationStatus {
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                if !usingServiceSession {
                    manager.requestWhenInUseAuthorization()
                }
            }
        case .authorizedAlways, .authorizedWhenInUse:
            return try await requestCurrentLocation()
        case .denied, .restricted:
            stopServiceSession()
            throw ActionDispatcher.ActionError.locationDenied
        @unknown default:
            stopServiceSession()
            throw ActionDispatcher.ActionError.locationDenied
        }
    }

    @discardableResult
    private func startWhenInUseServiceSessionIfAvailable() -> Bool {
        #if os(iOS) || os(tvOS) || os(visionOS)
        if #available(iOS 18.0, tvOS 18.0, visionOS 2.0, *) {
            serviceSession = CLServiceSession(authorization: .whenInUse)
            return true
        }
        #endif
        return false
    }

    private func stopServiceSession() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        if #available(iOS 18.0, tvOS 18.0, visionOS 2.0, *) {
            serviceSession?.invalidate()
            serviceSession = nil
        }
        #endif
    }

    private func requestCurrentLocation() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                complete(with: .failure(ActionDispatcher.ActionError.locationDenied))
            case .notDetermined:
                break
            @unknown default:
                complete(with: .failure(ActionDispatcher.ActionError.locationDenied))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            Task { @MainActor in self.complete(with: .failure(ActionDispatcher.ActionError.locationUnavailable)) }
            return
        }
        let coord = location.coordinate
        let value = "\(coord.latitude),\(coord.longitude)"
        Task { @MainActor in self.complete(with: .success(value)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.complete(with: .failure(error)) }
    }

    private func complete(with result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        stopServiceSession()
        switch result {
        case .success(let coordinate): continuation.resume(returning: coordinate)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }
}

struct MediaCaptureRequest: Equatable {
    enum Source: Equatable {
        case camera
        case photoLibrary
    }

    enum MediaType: Equatable {
        case image
        case video
    }

    let source: Source
    let mediaType: MediaType
    let allowsEditing: Bool
}

struct MediaPlaybackRequest: Equatable {
    let url: URL
}

struct ShareRequest: Equatable {
    var items: [ShareItem]
}

struct ShareItem: Equatable {
    enum Kind: Equatable {
        case text
        case url
        case imageData
        case fileURL
    }

    let kind: Kind
    var text: String?
    var url: URL?
    var data: Data?
    var contentType: String?

    init(kind: Kind, text: String? = nil, url: URL? = nil, data: Data? = nil, contentType: String? = nil) {
        self.kind = kind
        self.text = text
        self.url = url
        self.data = data
        self.contentType = contentType
    }
}

struct SnapshotResult: Equatable {
    let data: Data
    let contentType: String
}

struct VisionScanRequest: Equatable {
    let kind: String?
}

struct UtilityPickerRequest {
    let items: [UtilityPickerItem]
}

struct UtilityPickerItem {
    let text: String
    let value: Any?
    let action: JasonAction?
}

struct DatePickerRequest: Equatable {
    let initialValue: Int?
}

struct DatePickerResult: Equatable {
    let value: Int
}

enum UtilityNotificationKind: Equatable {
    case toast
    case banner
}

struct UtilityNotificationRequest: Equatable {
    let kind: UtilityNotificationKind
    let title: String
    let description: String?
    let styleType: String?
}

/// Executes Jasonette actions with success/error chaining.
@MainActor
public final class ActionDispatcher: ObservableObject {
    private let stateManager: StateManager
    private var navigationHandler: ((JasonHref) -> Void)?
    private var reloadHandler: (() -> Void)?
    private var alertHandler: ((String, String?) -> Void)?
    private var utilityNotificationHandler: ((UtilityNotificationRequest) -> Void)?
    private var renderHandler: ((String?) -> Void)?
    private var actionResolver: ((String) -> JasonAction?)?
    private var audioPlayHandler: ((URL) -> Void)?
    private var mediaCaptureHandler: ((MediaCaptureRequest) async throws -> [String: Any])?
    private var mediaPlaybackHandler: ((MediaPlaybackRequest) async throws -> Void)?
    private var shareHandler: ((ShareRequest) async throws -> Void)?
    private var snapshotHandler: (() async throws -> SnapshotResult)?
    private var addressBookHandler: (() async throws -> [[String: Any]])?
    private var visionScanHandler: ((VisionScanRequest) async throws -> [String: Any])?
    private var utilityPickerHandler: ((UtilityPickerRequest) async throws -> Int)?
    private var datePickerHandler: ((DatePickerRequest) async throws -> DatePickerResult)?
    private var geolocationProvider: GeolocationProviding = CoreLocationGeolocationProvider()
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

    func setUtilityNotificationHandler(_ handler: @escaping (UtilityNotificationRequest) -> Void) {
        self.utilityNotificationHandler = handler
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

    func setMediaCaptureHandler(_ handler: @escaping (MediaCaptureRequest) async throws -> [String: Any]) {
        self.mediaCaptureHandler = handler
    }

    func setMediaPlaybackHandler(_ handler: @escaping (MediaPlaybackRequest) async throws -> Void) {
        self.mediaPlaybackHandler = handler
    }

    func setShareHandler(_ handler: @escaping (ShareRequest) async throws -> Void) {
        self.shareHandler = handler
    }

    func setSnapshotHandler(_ handler: @escaping () async throws -> SnapshotResult) {
        self.snapshotHandler = handler
    }

    func setAddressBookHandler(_ handler: @escaping () async throws -> [[String: Any]]) {
        self.addressBookHandler = handler
    }

    func setVisionScanHandler(_ handler: @escaping (VisionScanRequest) async throws -> [String: Any]) {
        self.visionScanHandler = handler
    }

    func setUtilityPickerHandler(_ handler: @escaping (UtilityPickerRequest) async throws -> Int) {
        self.utilityPickerHandler = handler
    }

    func setDatePickerHandler(_ handler: @escaping (DatePickerRequest) async throws -> DatePickerResult) {
        self.datePickerHandler = handler
    }

    func setGeolocationProvider(_ provider: GeolocationProviding) {
        self.geolocationProvider = provider
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
            let errorActions = continuationActions(action.errorActions, fallback: action.error)
            guard !errorActions.isEmpty else {
                alertHandler?("Action failed", error.localizedDescription)
                return payload
            }

            var chainedPayload = payload
            for errorAction in errorActions {
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
            let renderPayload = options["data"]?.unwrapped ?? payload
            if let renderPayload {
                stateManager.set(["$jason": renderPayload])
            }
            let templateName = options["template"]?.string
            renderHandler?(templateName)
            return renderPayload

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
                    fresh: options["fresh"]?.bool,
                    options: options["options"]?.dictionary
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

        // Conversion
        case "$convert.csv":
            let converted = convertCSV(options["data"]?.string ?? payload as? String ?? "")
            stateManager.set(["$jason": converted])
            return converted

        case "$convert.rss":
            let converted = convertRSS(options["data"]?.string ?? payload as? String ?? "")
            stateManager.set(["$jason": converted])
            return converted

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
            showUtilityNotification(.toast, title: text, description: nil, styleType: options["type"]?.string)
            return payload

        case "$util.banner":
            let title = renderedString(options["title"], payload: payload)
                ?? renderedString(options["text"], payload: payload)
                ?? "Done"
            let description = renderedString(options["description"], payload: payload)
            showUtilityNotification(.banner, title: title, description: description, styleType: options["type"]?.string)
            return payload

        case "$util.picker":
            return try await utilityPicker(utilityPickerRequest(from: options), baseURL: baseURL, payload: payload)

        case "$util.datepicker":
            return try await datePicker(datePickerRequest(from: options))

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
            let coord = try await geolocationProvider.currentCoordinate()
            let coordinate: [String: Any] = ["coord": coord]
            stateManager.set(coordinate)
            return coordinate

        case "$media.camera":
            return try await captureMedia(request: mediaCaptureRequest(from: options, source: .camera))

        case "$media.picker":
            return try await captureMedia(request: mediaCaptureRequest(from: options, source: .photoLibrary))

        case "$util.share":
            try await share(shareRequest(from: options, payload: payload))
            return payload

        case "$snapshot":
            return try await snapshot()

        case "$media.play":
            try await playMedia(mediaPlaybackRequest(from: options, baseURL: baseURL))
            return payload

        case "$util.addressbook":
            return try await addressBook()

        case "$vision.scan":
            guard visionScanHandler != nil else {
                alertHandler?("Not implemented yet", "\(type) is recognized, but this platform cannot present the native scanner UI.")
                return payload
            }
            return try await visionScan(visionScanRequest(from: options))

        case "$script.include":
            stateManager.set([
                "_": "__jasonette_underscore__",
                "he": "__jasonette_he__",
            ])
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

    private func showUtilityNotification(
        _ kind: UtilityNotificationKind,
        title: String,
        description: String?,
        styleType: String?
    ) {
        let request = UtilityNotificationRequest(
            kind: kind,
            title: title,
            description: description,
            styleType: styleType
        )
        if let utilityNotificationHandler {
            utilityNotificationHandler(request)
        } else {
            alertHandler?(title, description)
        }
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
        context["$root"] = context["$jason"] ?? context
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

    // MARK: - Media

    private func mediaCaptureRequest(from options: [String: AnyCodable], source: MediaCaptureRequest.Source) -> MediaCaptureRequest {
        MediaCaptureRequest(
            source: source,
            mediaType: options["type"]?.string?.lowercased() == "video" ? .video : .image,
            allowsEditing: truthy(options["edit"]) || truthy(options["editing"])
        )
    }

    private func captureMedia(request: MediaCaptureRequest) async throws -> Any? {
        guard let mediaCaptureHandler else {
            alertHandler?("Camera unavailable", "This platform cannot present the native media capture UI.")
            throw ActionError.mediaCaptureUnavailable
        }

        do {
            let result = try await mediaCaptureHandler(request)
            stateManager.set(result)
            stateManager.set(["$jason": result])
            return result
        } catch ActionError.mediaCaptureCancelled {
            throw ActionError.mediaCaptureCancelled
        } catch {
            alertHandler?(request.source == .camera ? "Camera unavailable" : "Media picker unavailable", error.localizedDescription)
            throw error
        }
    }

    private func mediaPlaybackRequest(from options: [String: AnyCodable], baseURL: URL?) throws -> MediaPlaybackRequest {
        guard let urlString = options["url"]?.string,
              let url = JasonURL.resolve(urlString, against: baseURL) else {
            throw ActionError.invalidURL
        }
        guard let scheme = url.scheme?.lowercased(),
              DocumentLoader.allowedSchemes.contains(scheme) else {
            throw ActionError.blockedURL
        }
        return MediaPlaybackRequest(url: url)
    }

    private func playMedia(_ request: MediaPlaybackRequest) async throws {
        guard let mediaPlaybackHandler else {
            alertHandler?("Video unavailable", "This platform cannot present the native media playback UI.")
            throw ActionError.mediaPlaybackUnavailable
        }
        do {
            try await mediaPlaybackHandler(request)
        } catch {
            alertHandler?("Video unavailable", error.localizedDescription)
            throw error
        }
    }

    private func shareRequest(from options: [String: AnyCodable], payload: Any?) -> ShareRequest {
        var items: [ShareItem] = []

        if let array = options["items"]?.array {
            for item in array {
                if let parsed = shareItem(from: item) {
                    items.append(parsed)
                }
            }
        }

        if let text = options["text"]?.string, !text.isEmpty {
            items.append(ShareItem(kind: .text, text: text))
        }
        if let urlString = options["url"]?.string, let url = URL(string: urlString) {
            items.append(ShareItem(kind: .url, url: url))
        }
        if let dataString = options["data"]?.string, let data = Self.base64Data(from: dataString) {
            items.append(ShareItem(kind: .imageData, data: data, contentType: "image/jpeg"))
        }

        if items.isEmpty, let payloadString = payload as? String, !payloadString.isEmpty {
            items.append(ShareItem(kind: .text, text: payloadString))
        }

        return ShareRequest(items: items)
    }

    private func shareItem(from item: AnyCodable) -> ShareItem? {
        if let string = item.string, !string.isEmpty {
            return ShareItem(kind: .text, text: string)
        }
        guard let dictionary = item.dictionary else { return nil }
        let type = dictionary["type"]?.string?.lowercased()

        if type == "image", let dataString = dictionary["data"]?.string, let data = Self.base64Data(from: dataString) {
            return ShareItem(kind: .imageData, data: data, contentType: dictionary["content_type"]?.string ?? "image/jpeg")
        }
        if type == "video", let fileURLString = dictionary["file_url"]?.string, let url = URL(string: fileURLString) {
            return ShareItem(kind: .fileURL, url: url)
        }
        if let urlString = dictionary["url"]?.string, let url = URL(string: urlString) {
            return ShareItem(kind: .url, url: url)
        }
        if let text = dictionary["text"]?.string ?? dictionary["title"]?.string, !text.isEmpty {
            return ShareItem(kind: .text, text: text)
        }
        return nil
    }

    private func share(_ request: ShareRequest) async throws {
        guard !request.items.isEmpty else {
            throw ActionError.emptyShareItems
        }
        guard let shareHandler else {
            alertHandler?("Share unavailable", "This platform cannot present the native share sheet.")
            throw ActionError.shareUnavailable
        }
        try await shareHandler(request)
    }

    private func snapshot() async throws -> Any? {
        guard let snapshotHandler else {
            alertHandler?("Snapshot unavailable", "This platform cannot capture the current screen.")
            throw ActionError.snapshotUnavailable
        }
        let result = try await snapshotHandler()
        let payload: [String: Any] = [
            "data": result.data.base64EncodedString(),
            "media_type": "image",
            "content_type": result.contentType
        ]
        stateManager.set(payload)
        stateManager.set(["$jason": payload])
        return payload
    }

    private func addressBook() async throws -> Any? {
        guard let addressBookHandler else {
            alertHandler?("Contacts unavailable", "This platform cannot access the native address book.")
            throw ActionError.addressBookUnavailable
        }

        do {
            let contacts = try await addressBookHandler()
            stateManager.set(["$jason": contacts])
            return contacts
        } catch {
            alertHandler?("Contacts unavailable", error.localizedDescription)
            throw error
        }
    }

    private func utilityPickerRequest(from options: [String: AnyCodable]) -> UtilityPickerRequest {
        let items = options["items"]?.array?.map { item -> UtilityPickerItem in
            if let dictionary = item.dictionary {
                let text = dictionary["text"]?.string
                    ?? dictionary["title"]?.string
                    ?? dictionary["value"]?.string
                    ?? "Item"
                return UtilityPickerItem(
                    text: text,
                    value: dictionary["value"]?.unwrapped,
                    action: actionFromOption(dictionary["action"])
                )
            }
            let text = item.string ?? String(describing: item.unwrapped)
            return UtilityPickerItem(text: text, value: item.unwrapped, action: nil)
        } ?? []
        return UtilityPickerRequest(items: items)
    }

    private func utilityPicker(_ request: UtilityPickerRequest, baseURL: URL?, payload: Any?) async throws -> Any? {
        guard !request.items.isEmpty else {
            alertHandler?("Picker", "No picker items supplied.")
            throw ActionError.emptyPickerItems
        }
        guard let utilityPickerHandler else {
            alertHandler?("Picker", request.items.map(\.text).joined(separator: "\n"))
            return payload
        }

        let selectedIndex = try await utilityPickerHandler(request)
        guard request.items.indices.contains(selectedIndex) else {
            throw ActionError.invalidPickerSelection
        }
        let item = request.items[selectedIndex]
        let selectedPayload: [String: Any] = [
            "index": selectedIndex,
            "value": item.value ?? selectedIndex,
            "text": item.text
        ]
        stateManager.set(selectedPayload)
        stateManager.set(["$jason": selectedPayload])
        if let itemAction = item.action {
            return await execute(itemAction, baseURL: baseURL, payload: selectedPayload) ?? selectedPayload
        }
        return selectedPayload
    }

    private func datePickerRequest(from options: [String: AnyCodable]) -> DatePickerRequest {
        DatePickerRequest(initialValue: options["value"]?.int ?? options["timestamp"]?.int)
    }

    private func datePicker(_ request: DatePickerRequest) async throws -> Any? {
        let result: DatePickerResult
        if let datePickerHandler {
            result = try await datePickerHandler(request)
        } else {
            result = DatePickerResult(value: Int(Date().timeIntervalSince1970))
            alertHandler?("Date", Date(timeIntervalSince1970: TimeInterval(result.value)).formatted())
        }
        let payload: [String: Any] = ["value": result.value]
        stateManager.set(payload)
        stateManager.set(["$jason": payload])
        return payload
    }

    private func visionScanRequest(from options: [String: AnyCodable]) -> VisionScanRequest {
        VisionScanRequest(kind: options["type"]?.string?.lowercased())
    }

    private func visionScan(_ request: VisionScanRequest) async throws -> Any? {
        guard let visionScanHandler else {
            throw ActionError.visionScanUnavailable
        }
        let result = try await visionScanHandler(request)
        stateManager.set(result)
        stateManager.set(["$jason": result])
        return result
    }

    private func truthy(_ value: AnyCodable?) -> Bool {
        guard let value else { return false }
        if let bool = value.bool { return bool }
        if let int = value.int { return int != 0 }
        if let string = value.string?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            return ["true", "yes", "1"].contains(string)
        }
        return false
    }

    private static func base64Data(from value: String) -> Data? {
        let base64: String
        if let comma = value.firstIndex(of: ","), value[..<comma].contains("base64") {
            base64 = String(value[value.index(after: comma)...])
        } else {
            base64 = value
        }
        return Data(base64Encoded: base64)
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

    // MARK: - Conversion

    private func convertCSV(_ text: String) -> [[String: Any]] {
        let rows = parseCSVRows(text)
        guard let headerRow = rows.first else { return [] }
        let headers = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return rows.dropFirst().compactMap { row in
            guard row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
            var object: [String: Any] = [:]
            for (index, header) in headers.enumerated() where !header.isEmpty {
                let value = index < row.count ? row[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                object[header] = value
            }
            return object
        }
    }

    private func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()

        while let char = iterator.next() {
            if char == "\"" {
                if inQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append(next)
                    } else {
                        inQuotes = false
                        if next == "," {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else if next != "\r" {
                            field.append(next)
                        }
                    }
                } else {
                    inQuotes.toggle()
                }
            } else if char == ",", !inQuotes {
                row.append(field)
                field = ""
            } else if char == "\n", !inQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if char != "\r" || inQuotes {
                field.append(char)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private func convertRSS(_ text: String) -> [[String: Any]] {
        let itemPattern = #"(?is)<item\b[^>]*>(.*?)</item>"#
        guard let regex = try? NSRegularExpression(pattern: itemPattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let item = String(text[range])
            var object: [String: Any] = [:]
            if let title = firstXMLValue(named: "title", in: item) { object["title"] = title }
            if let author = firstXMLValue(named: "dc:creator", in: item)
                ?? firstXMLValue(named: "author", in: item) {
                object["author"] = author
            }
            if let description = firstXMLValue(named: "description", in: item) { object["description"] = description }
            if let link = firstXMLValue(named: "link", in: item) { object["url"] = link }
            if let imageURL = firstXMLAttribute(named: "url", inFirstTagMatching: #"(?is)<media:(?:content|thumbnail)\b[^>]*>"#, text: item)
                ?? firstXMLAttribute(named: "href", inFirstTagMatching: #"(?is)<enclosure\b[^>]*>"#, text: item)
                ?? firstXMLAttribute(named: "url", inFirstTagMatching: #"(?is)<enclosure\b[^>]*>"#, text: item) {
                object["image"] = ["url": imageURL]
            }
            return object.isEmpty ? nil : object
        }
    }

    private func firstXMLValue(named name: String, in text: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = "(?is)<\(escaped)\\b[^>]*>(?:<!\\[CDATA\\[(.*?)\\]\\]>|(.*?))</\(escaped)>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        let captureIndex = match.range(at: 1).location != NSNotFound ? 1 : 2
        guard let range = Range(match.range(at: captureIndex), in: text) else { return nil }
        return decodeXMLEntities(String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func firstXMLAttribute(named name: String, inFirstTagMatching tagPattern: String, text: String) -> String? {
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern),
              let tagMatch = tagRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let tagRange = Range(tagMatch.range, in: text)
        else { return nil }
        let tag = String(text[tagRange])
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let attrPattern = "\\b\(escapedName)\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let attrRegex = try? NSRegularExpression(pattern: attrPattern),
              let attrMatch = attrRegex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let attrRange = Range(attrMatch.range(at: 1), in: tag)
        else { return nil }
        return decodeXMLEntities(String(tag[attrRange]))
    }

    private func decodeXMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    enum ActionError: Error {
        case invalidURL
        case blockedURL
        case httpError(Int)
        case locationUnavailable
        case locationDenied
        case locationRequestInProgress
        case mediaCaptureUnavailable
        case mediaCapturePermissionDenied
        case mediaCaptureCancelled
        case mediaPlaybackUnavailable
        case shareUnavailable
        case emptyShareItems
        case snapshotUnavailable
        case addressBookUnavailable
        case addressBookPermissionDenied
        case visionScanUnavailable
        case visionScanPermissionDenied
        case visionScanCancelled
        case emptyPickerItems
        case invalidPickerSelection
        case utilityPickerCancelled
        case datePickerCancelled
    }
}

extension ActionDispatcher.ActionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .blockedURL:
            return "The URL uses a blocked scheme."
        case .httpError(let status):
            return "The request failed with HTTP status \(status)."
        case .locationUnavailable:
            return "Location services are unavailable."
        case .locationDenied:
            return "Location permission was denied."
        case .locationRequestInProgress:
            return "A location request is already in progress."
        case .mediaCaptureUnavailable:
            return "Media capture is unavailable on this device."
        case .mediaCapturePermissionDenied:
            return "Camera permission was denied. Enable camera access in Settings to use this Jasonette action."
        case .mediaCaptureCancelled:
            return "Media capture was cancelled."
        case .mediaPlaybackUnavailable:
            return "Media playback is unavailable on this device."
        case .shareUnavailable:
            return "Sharing is unavailable on this device."
        case .emptyShareItems:
            return "No shareable items were supplied."
        case .snapshotUnavailable:
            return "Snapshot capture is unavailable."
        case .addressBookUnavailable:
            return "Address book access is unavailable on this device."
        case .addressBookPermissionDenied:
            return "Contacts permission was denied. Enable contacts access in Settings to use this Jasonette action."
        case .visionScanUnavailable:
            return "Barcode scanning is unavailable on this device."
        case .visionScanPermissionDenied:
            return "Camera permission was denied. Enable camera access in Settings to scan codes."
        case .visionScanCancelled:
            return "Barcode scanning was cancelled."
        case .emptyPickerItems:
            return "No picker items were supplied."
        case .invalidPickerSelection:
            return "The picker selection was invalid."
        case .utilityPickerCancelled:
            return "Picker selection was cancelled."
        case .datePickerCancelled:
            return "Date selection was cancelled."
        }
    }
}
