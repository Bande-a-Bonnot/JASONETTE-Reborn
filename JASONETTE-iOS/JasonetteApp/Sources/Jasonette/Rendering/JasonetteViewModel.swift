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
    private var activeTemplateName: String = "body"

    struct AlertConfig: Identifiable {
        let id = UUID()
        let title: String
        let description: String?
    }

    private let url: URL?
    private var document: JasonDocument?
    private let loader = DocumentLoader()
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

    init(url: URL, onNavigate: ((NavigationRequest) -> Void)? = nil) {
        self.url = url
        self.document = nil
        self.actionDispatcher = ActionDispatcher(stateManager: stateManager)
        self.onNavigate = onNavigate ?? { _ in }
        wireHandlers()
    }

    init(document: JasonDocument, onNavigate: ((NavigationRequest) -> Void)? = nil) {
        self.url = nil
        self.document = document
        self.actionDispatcher = ActionDispatcher(stateManager: stateManager)
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
        actionDispatcher.setRenderHandler { [weak self] templateName in
            guard let self else { return }
            let name = templateName ?? "body"
            if self.document?.jason.head?.templates?[name] != nil {
                self.activeTemplateName = name
            }
            if let doc = self.document { self.render(doc) }
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
            if document == nil, let url {
                document = try await loader.load(from: url)
            }
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
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            loadState = .error(error.localizedDescription)
        }
    }

    private func render(_ doc: JasonDocument) {
        let head = doc.jason.head
        let data = head?.data?.compactMapValues { $0.unwrapped } ?? [:]
        let context = data.merging(stateManager.local) { _, new in new }

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

    func handleHref(_ href: JasonHref) {
        if href.view == "$back" { onNavigate(.back); return }
        if href.view == "$close" { onNavigate(.close); return }

        guard let urlStr = href.url, let url = URL(string: urlStr) else { return }

        let appSchemes: Set<String> = ["http", "https", "mailto", "tel", "sms"]
        let allowed = href.view == "app" ? appSchemes : DocumentLoader.allowedSchemes
        guard let scheme = url.scheme?.lowercased(), allowed.contains(scheme) else { return }

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

