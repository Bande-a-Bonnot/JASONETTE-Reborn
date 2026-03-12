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

    init(url: URL) {
        self.url = url
        self.document = nil
        self.actionDispatcher = ActionDispatcher(stateManager: stateManager)
        wireHandlers()
    }

    init(document: JasonDocument) {
        self.url = nil
        self.document = document
        self.actionDispatcher = ActionDispatcher(stateManager: stateManager)
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
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    private func render(_ doc: JasonDocument) {
        let head = doc.jason.head
        let data = head?.data?.compactMapValues { $0.unwrapped } ?? [:]
        let context = data.merging(stateManager.local) { _, new in new }

        if let templates = head?.templates?.body {
            let rendered = TemplateEngine.render(templates.unwrapped, context: context)

            guard JSONSerialization.isValidJSONObject(rendered) else {
                #if DEBUG
                print("[Jasonette] render: template produced non-serializable output, falling back to raw document")
                #endif
                renderedRoot = doc.jason
                return
            }
            do {
                let renderedData = try JSONSerialization.data(withJSONObject: rendered)
                var root = try decoder.decode(JasonRoot.self, from: renderedData)
                root.head = head
                renderedRoot = root
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
        // Handle $back
        if href.view == "$back" {
            NotificationCenter.default.post(
                name: .jasonetteNavigate,
                object: nil,
                userInfo: ["back": true]
            )
            return
        }

        // Handle $close
        if href.view == "$close" {
            NotificationCenter.default.post(
                name: .jasonetteNavigate,
                object: nil,
                userInfo: ["close": true]
            )
            return
        }

        if let urlStr = href.url, let url = URL(string: urlStr) {
            // Validate scheme before allowing navigation
            guard let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else { return }
            NotificationCenter.default.post(
                name: .jasonetteNavigate,
                object: nil,
                userInfo: ["href": href, "url": url]
            )
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

// MARK: - Navigation notification

public extension Notification.Name {
    static let jasonetteNavigate = Notification.Name("jasonetteNavigate")
}
