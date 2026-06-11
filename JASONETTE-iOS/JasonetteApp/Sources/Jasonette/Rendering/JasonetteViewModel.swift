import Foundation
import SwiftUI

/// View model that manages loading, rendering, and state for a Jasonette document.
@MainActor
public final class JasonetteViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published var loadState: LoadState = .idle
    @Published var renderedRoot: JasonRoot?
    @Published var alertConfig: AlertConfig?
    @Published var transientNotificationConfig: TransientNotificationConfig?
    private var transientNotificationDismissTask: Task<Void, Never>?
    private var activeTemplateName: String = "body"
    private var unsupportedCameraBackgroundAlertSignature: String?

    struct AlertConfig: Identifiable {
        let id = UUIDv7.generate()
        let title: String
        let description: String?
    }

    struct TransientNotificationConfig: Identifiable, Equatable {
        let id = UUIDv7.generate()
        let kind: UtilityNotificationKind
        let title: String
        let description: String?
        let styleType: String?
    }

    private let url: URL?
    private let initialParams: [String: AnyCodable]
    private(set) var documentURL: URL?
    private var document: JasonDocument?
    /// True once the preloaded seed document (if any) has been rendered. After
    /// that, `load()` refetches from `url` — otherwise `$reload`, retry, and
    /// pull-to-refresh-without-`$pull` would forever re-render the stale seed.
    private var seedConsumed: Bool = false
    private let loader: DocumentLoader
    private let decoder = JSONDecoder()
    private var loadTask: Task<Void, Never>?
    let stateManager = StateManager()
    let actionDispatcher: ActionDispatcher

    /// Scoped navigation dispatch installed by the enclosing
    /// `JasonetteNavigationView`. The root container installs one, each modal
    /// installs its own — so navigation inside a modal never leaks into the
    /// parent's stack. Default no-op keeps the viewmodel usable in tests and
    /// previews without navigation wiring.
    let onNavigate: (NavigationRequest) -> Void

    init(
        url: URL,
        initialParams: [String: AnyCodable] = [:],
        onNavigate: ((NavigationRequest) -> Void)? = nil,
        loader: DocumentLoader = DocumentLoader()
    ) {
        self.url = url
        self.initialParams = initialParams
        self.documentURL = url
        self.document = nil
        self.loader = loader
        self.actionDispatcher = ActionDispatcher(stateManager: stateManager, documentURL: url)
        self.onNavigate = onNavigate ?? { _ in }
        wireHandlers()
    }

    init(document: JasonDocument, initialParams: [String: AnyCodable] = [:], onNavigate: ((NavigationRequest) -> Void)? = nil) {
        self.url = nil
        self.initialParams = initialParams
        self.documentURL = nil
        self.document = document
        self.loader = DocumentLoader()
        self.actionDispatcher = ActionDispatcher(stateManager: stateManager)
        self.onNavigate = onNavigate ?? { _ in }
        wireHandlers()
    }

    /// Seed the VM with a document already fetched by the bootstrap and the
    /// URL it came from. First `load()` renders the seed without a network
    /// round-trip; subsequent `load()`/`reload()` refetch from `url`.
    init(
        url: URL,
        preloadedDoc: JasonDocument,
        documentURL: URL? = nil,
        initialParams: [String: AnyCodable] = [:],
        onNavigate: ((NavigationRequest) -> Void)? = nil,
        loader: DocumentLoader = DocumentLoader()
    ) {
        let resolvedDocumentURL = documentURL ?? url
        self.url = url
        self.initialParams = initialParams
        self.documentURL = resolvedDocumentURL
        self.document = preloadedDoc
        self.loader = loader
        self.actionDispatcher = ActionDispatcher(stateManager: stateManager, documentURL: resolvedDocumentURL)
        self.onNavigate = onNavigate ?? { _ in }
        wireHandlers()
    }

    private func wireHandlers() {
        actionDispatcher.setNavigationHandler { [weak self] href in
            self?.handleHref(href)
        }
        actionDispatcher.setReloadHandler { [weak self] in
            self?.reload()
        }
        actionDispatcher.setAlertHandler { [weak self] title, description in
            self?.alertConfig = AlertConfig(title: title, description: description)
        }
        actionDispatcher.setUtilityNotificationHandler { [weak self] request in
            self?.showTransientNotification(request)
        }
        actionDispatcher.setRenderHandler { [weak self] templateName in
            guard let self else { return }
            let name = templateName ?? "body"
            if self.document?.jason.head?.templates?[name] != nil {
                self.activeTemplateName = name
            }
            if let doc = self.document, !self.render(doc) {
                self.loadState = .error(Self.templateRenderFailureMessage)
            }
        }
        actionDispatcher.setActionResolver { [weak self] name in
            self?.document?.jason.head?.actions?[name]
        }
    }

    func loadIfNeeded() async {
        guard loadState == .idle else { return }
        loadTask?.cancel()
        loadTask = Task { await load() }
        await loadTask?.value
    }

    func reload() {
        loadTask?.cancel()
        loadState = .loading
        loadTask = Task { await load() }
    }

    func load() async {
        loadState = .loading
        do {
            // Fetch from URL except on the very first load when a preloaded
            // seed is waiting. That seed is rendered once, then every
            // subsequent load() refetches so `$reload`/retry/pull work.
            let hasUnconsumedSeed = document != nil && !seedConsumed
            if let url, !hasUnconsumedSeed {
                let loaded = try await loader.loadWithMetadata(from: url)
                document = loaded.document
                documentURL = loaded.url
                actionDispatcher.setDocumentURL(loaded.url)
            }
            seedConsumed = true
            guard var doc = document else {
                loadState = .error("No document")
                return
            }
            doc = await resolveHeadDataMixins(in: doc, baseURL: documentURL)
            document = doc
            let initialRenderSucceeded = render(doc)
            let loadAction = doc.jason.head?.actions?["$load"]
            guard initialRenderSucceeded || loadAction != nil else {
                loadState = .error(Self.templateRenderFailureMessage)
                return
            }
            loadState = .loaded

            // Fire $load lifecycle. Some legacy templates intentionally need
            // `$load` to seed state before their first successful typed body
            // decode (for example dynamic layer style objects).
            if let loadAction {
                await actionDispatcher.execute(loadAction)
                // Re-render after $load modifies state
                if let d = document, !render(d) {
                    loadState = .error(Self.templateRenderFailureMessage)
                    return
                }
            }
            if let renderedRoot,
               renderedRoot.body?.background?.dictionary?["type"]?.string == "camera",
               let readyAction = doc.jason.head?.actions?["$vision.ready"] {
                await actionDispatcher.execute(readyAction)
                if let d = document, !render(d) {
                    loadState = .error(Self.templateRenderFailureMessage)
                    return
                }
            }
            if let renderedRoot {
                showUnsupportedCameraBackgroundAlertIfNeeded(renderedRoot)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            loadState = .error(error.localizedDescription)
        }
    }

    private func showUnsupportedCameraBackgroundAlertIfNeeded(_ root: JasonRoot) {
        guard root.body?.background?.dictionary?["type"]?.string == "camera" else { return }

        guard root.head?.actions?["$vision.ready"] == nil else { return }

        let hasVisionLifecycle = root.head?.actions?["$vision.onscan"] != nil
            || root.head?.actions?.values.contains { $0.type == "$vision.scan" } == true
        guard hasVisionLifecycle else { return }

        let signature = [root.head?.title ?? "", String(describing: root.body?.background?.unwrapped)]
            .joined(separator: "|")
        guard unsupportedCameraBackgroundAlertSignature != signature else { return }

        unsupportedCameraBackgroundAlertSignature = signature
        alertConfig = AlertConfig(
            title: "Not implemented yet",
            description: "Camera-backed vision scanning is recognized, but this iOS renderer does not implement the live camera background yet."
        )
    }

    private func resolveHeadDataMixins(in doc: JasonDocument, baseURL: URL?) async -> JasonDocument {
        guard let head = doc.jason.head,
              let data = head.data,
              let mixinURLString = data["@"]?.string,
              let mixinURL = JasonURL.resolve(mixinURLString, against: baseURL)
        else { return doc }

        do {
            let loaded = try await loader.loadJSON(from: mixinURL).value
            guard let remoteData = loaded as? [String: Any] else { return doc }
            var merged = remoteData
            for (key, value) in data where key != "@" {
                merged[key] = value.unwrapped
            }
            var root = doc.jason
            var resolvedHead = head
            resolvedHead.data = merged.mapValues { wrapAsAnyCodable($0) }
            root.head = resolvedHead
            return JasonDocument(jason: root)
        } catch {
            #if DEBUG
            print("[Jasonette] data mixin load failed (\(error)); rendering inline data")
            #endif
            return doc
        }
    }

    private static let templateRenderFailureMessage = "Template render failed; showing error instead of silently discarding the template."

    @discardableResult
    private func render(_ doc: JasonDocument) -> Bool {
        let head = doc.jason.head
        let data = head?.data?.compactMapValues { $0.unwrapped } ?? [:]
        var context = data.merging(stateManager.local) { _, new in new }
        if context["$jason"] == nil {
            context["$jason"] = context
        }
        context["$root"] = context["$jason"]
        if !initialParams.isEmpty {
            context["$params"] = initialParams.mapValues { $0.unwrapped }
        }
        context["$get"] = stateManager.local
        context["$cache"] = stateManager.cache

        if let template = head?.templates?[activeTemplateName] {
            let rendered = TemplateEngine.render(template.unwrapped, context: context)

            guard JSONSerialization.isValidJSONObject(rendered) else {
                #if DEBUG
                print("[Jasonette] render: template produced non-serializable output, falling back to raw document")
                #endif
                renderedRoot = doc.jason
                return doc.jason.hasRenderableBodyContent
            }
            do {
                let renderedData = try JSONSerialization.data(withJSONObject: rendered)
                let body = try decoder.decode(JasonBody.self, from: renderedData)
                renderedRoot = JasonRoot(head: head, body: body)
                return true
            } catch {
                #if DEBUG
                print("[Jasonette] render: template decode failed (\(error)), falling back to raw document")
                #endif
                renderedRoot = doc.jason
                return doc.jason.hasRenderableBodyContent
            }
        } else {
            renderedRoot = doc.jason
            return true
        }
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

    private func showTransientNotification(_ request: UtilityNotificationRequest) {
        transientNotificationDismissTask?.cancel()
        transientNotificationConfig = TransientNotificationConfig(
            kind: request.kind,
            title: request.title,
            description: request.description,
            styleType: request.styleType
        )
        transientNotificationDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.transientNotificationConfig = nil }
        }
    }

    func handleHref(_ href: JasonHref) {
        if href.view == "$back" { onNavigate(.back); return }
        if href.view == "$close" { onNavigate(.close); return }

        guard let urlStr = href.url else { return }

        let allowed = href.view == "app" ? DocumentLoader.appSchemes : DocumentLoader.allowedSchemes
        guard let url = JasonURL.resolve(urlStr, against: documentURL, allowedSchemes: allowed) else { return }

        switch href.view {
        case "web":
            onNavigate(.web(url))
        case "app":
            onNavigate(.app(url))
        default:
            switch href.transition {
            case "modal":  onNavigate(.modal(url, href.options ?? [:]))
            case "switch": onNavigate(.switchTab(url))
            default:       onNavigate(.push(url))
            }
        }
    }

    func handleAction(_ action: JasonAction) {
        Task { await actionDispatcher.execute(action) }
    }

    func handlePull() async {
        guard let pullAction = document?.jason.head?.actions?["$pull"] else {
            await load()
            return
        }
        await actionDispatcher.execute(pullAction)
        if let doc = document, !render(doc) {
            loadState = .error(Self.templateRenderFailureMessage)
        }
    }
}

private extension JasonRoot {
    var hasRenderableBodyContent: Bool {
        guard let body else { return false }
        if body.background != nil || body.header != nil || body.footer != nil { return true }
        if body.sections?.isEmpty == false { return true }
        if body.layers?.isEmpty == false { return true }
        return false
    }
}

