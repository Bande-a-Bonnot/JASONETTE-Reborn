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

    init(url: URL, onNavigate: ((NavigationRequest) -> Void)? = nil, loader: DocumentLoader = DocumentLoader()) {
        self.url = url
        self.documentURL = url
        self.document = nil
        self.loader = loader
        self.actionDispatcher = ActionDispatcher(stateManager: stateManager, documentURL: url)
        self.onNavigate = onNavigate ?? { _ in }
        wireHandlers()
    }

    init(document: JasonDocument, onNavigate: ((NavigationRequest) -> Void)? = nil) {
        self.url = nil
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
        onNavigate: ((NavigationRequest) -> Void)? = nil,
        loader: DocumentLoader = DocumentLoader()
    ) {
        let resolvedDocumentURL = documentURL ?? url
        self.url = url
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
            if let doc = self.document { self.render(doc) }
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
            guard let doc = document else {
                loadState = .error("No document")
                return
            }
            render(doc)
            loadState = .loaded

            // Fire $load lifecycle
            if let loadAction = doc.jason.head?.actions?["$load"] {
                await actionDispatcher.execute(loadAction)
                // Re-render after $load modifies state
                if let d = document { render(d) }
            }
            if let renderedRoot,
               renderedRoot.body?.background?.dictionary?["type"]?.string == "camera",
               let readyAction = doc.jason.head?.actions?["$vision.ready"] {
                await actionDispatcher.execute(readyAction)
                if let d = document { render(d) }
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

    private func render(_ doc: JasonDocument) {
        let head = doc.jason.head
        let data = head?.data?.compactMapValues { $0.unwrapped } ?? [:]
        var context = data.merging(stateManager.local) { _, new in new }
        context["$get"] = stateManager.local
        context["$cache"] = stateManager.cache

        if let template = head?.templates?[activeTemplateName] {
            let rendered = TemplateEngine.render(template.unwrapped, context: context)

            guard JSONSerialization.isValidJSONObject(rendered) else {
                #if DEBUG
                print("[Jasonette] render: template produced non-serializable output, falling back to raw document")
                #endif
                renderedRoot = doc.jason
                return
            }
            do {
                let renderedData = try JSONSerialization.data(withJSONObject: rendered)
                let body = try decoder.decode(JasonBody.self, from: renderedData)
                renderedRoot = JasonRoot(head: head, body: body)
            } catch {
                #if DEBUG
                print("[Jasonette] render: template decode failed (\(error)), falling back to raw document")
                #endif
                renderedRoot = doc.jason
            }
        } else {
            renderedRoot = doc.jason
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
            case "modal":  onNavigate(.modal(url))
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
        if let doc = document { render(doc) }
    }
}

