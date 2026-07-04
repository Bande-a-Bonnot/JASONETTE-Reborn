import Foundation

/// Loads and decodes $jason documents from URLs or local data.
public final class DocumentLoader: Sendable {
    public struct LoadedDocument: Sendable {
        public let document: JasonDocument
        public let url: URL

        public init(document: JasonDocument, url: URL) {
            self.document = document
            self.url = url
        }
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    /// Create a loader. `loadWithMetadata(from:)` installs a per-request task
    /// delegate to enforce redirect scheme validation; injected sessions should
    /// not depend on custom URLSession delegate callbacks (redirect, auth,
    /// trust, metrics, etc.) for metadata-preserving document loads.
    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// Schemes accepted for document URLs (HTTP fetch). Used by
    /// `DocumentLoader.load`, `ActionDispatcher` `$href`, footer-tab
    /// `.document` / `.web` construction.
    static let allowedSchemes: Set<String> = ["http", "https"]

    /// Schemes accepted for shell footer-tab icon assets. Kept separate from
    /// document URL policy so icon compatibility does not drift if document
    /// fetch schemes ever change; non-tab image policy is tracked separately.
    static let imageSchemes: Set<String> = ["http", "https"]

    /// Schemes accepted for `href.view == "app"` external-app navigation.
    /// Superset of `allowedSchemes`: also opens `mailto:` / `tel:` / `sms:`
    /// via the system. Used by `JasonetteViewModel.handleHref`, the nav
    /// view's `.app` dispatch, and footer-tab `.app` construction.
    static let appSchemes: Set<String> = ["http", "https", "mailto", "tel", "sms"]

    /// Load a document from a URL. This legacy API preserves injected-session
    /// delegate behavior by using `URLSession.data(from:)`; shell bootstrap
    /// code that needs redirect metadata uses `loadWithMetadata(from:)`.
    public func load(from url: URL) async throws -> JasonDocument {
        guard let scheme = url.scheme?.lowercased(),
              Self.allowedSchemes.contains(scheme) else {
            throw DocumentError.blockedURL
        }
        let (data, response) = try await session.data(from: url)
        let responseURL = response.url ?? url
        guard let responseScheme = responseURL.scheme?.lowercased(),
              Self.allowedSchemes.contains(responseScheme) else {
            throw DocumentError.blockedURL
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DocumentError.httpError(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        return try decode(data)
    }

    /// Load a document and return the final response URL. The final URL matters
    /// for resolving authored relative references after HTTP redirects. Used by
    /// shell bootstrap and normal `JasonetteViewModel` URL loads so final
    /// document-base metadata is preserved consistently. Redirect scheme
    /// validation is enforced with a request-scoped task delegate, so custom
    /// URLSession delegate callbacks are not part of `DocumentLoader`'s
    /// supported extension surface.
    public func loadWithMetadata(from url: URL) async throws -> LoadedDocument {
        let loaded = try await loadRawJSONWithMetadata(from: url, validatingRedirects: true)
        let data = try JSONSerialization.data(withJSONObject: loaded.value, options: [])
        return LoadedDocument(document: try decode(data), url: loaded.url)
    }

    /// Load a document after expanding legacy Jasonette include directives.
    /// This supports older Jasonpedia/WebContainer documents that put a `+`
    /// include at the top level before a `$jason` document exists, as well as
    /// nested `+`, `@`, and `$document...` references inside decoded documents.
    public func loadResolvingIncludesWithMetadata(from url: URL) async throws -> LoadedDocument {
        let loaded = try await loadRawJSONWithMetadata(from: url, validatingRedirects: true)
        let resolved = try await resolveLegacyIncludes(in: loaded.value, baseURL: loaded.url)
        let data = try JSONSerialization.data(withJSONObject: resolved, options: [])
        return LoadedDocument(document: try decode(data), url: loaded.url)
    }

    /// Load an arbitrary JSON resource with the same HTTP/scheme policy used
    /// for Jasonette documents. Used by legacy `head.data: { "@": url }`
    /// data mixins in Jasonpedia examples.
    public func loadJSON(from url: URL) async throws -> (value: Any, url: URL) {
        try await loadRawJSONWithMetadata(from: url, validatingRedirects: false)
    }

    /// Resolve legacy Jasonette include directives in an already-loaded JSON
    /// object. `baseURL` is used for relative remote includes.
    public func resolveLegacyIncludes(in value: Any, baseURL: URL?) async throws -> Any {
        let root: Any
        if let included = try await applyingIncludeDirectiveIfPresent(
            in: value,
            documentRoot: value,
            baseURL: baseURL,
            stack: [],
            depth: 0
        ) {
            root = included
        } else {
            root = value
        }
        return try await resolveLegacyIncludes(
            in: root,
            documentRoot: root,
            baseURL: baseURL,
            stack: [],
            depth: 0
        )
    }

    private static let maxIncludeDepth = 16

    private func loadRawJSONWithMetadata(
        from url: URL,
        validatingRedirects: Bool
    ) async throws -> (value: Any, url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              Self.allowedSchemes.contains(scheme) else {
            throw DocumentError.blockedURL
        }
        let data: Data
        let response: URLResponse
        if validatingRedirects {
            let redirectDelegate = RedirectSchemeValidator()
            (data, response) = try await session.data(for: URLRequest(url: url), delegate: redirectDelegate)
            if redirectDelegate.didBlockRedirect {
                throw DocumentError.blockedURL
            }
        } else {
            (data, response) = try await session.data(from: url)
        }
        let responseURL = response.url ?? url
        guard let responseScheme = responseURL.scheme?.lowercased(),
              Self.allowedSchemes.contains(responseScheme) else {
            throw DocumentError.blockedURL
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DocumentError.httpError(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        return (try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]), responseURL)
    }

    private func resolveLegacyIncludes(
        in value: Any,
        documentRoot: Any,
        baseURL: URL?,
        stack: Set<String>,
        depth: Int
    ) async throws -> Any {
        if let included = try await applyingIncludeDirectiveIfPresent(
            in: value,
            documentRoot: documentRoot,
            baseURL: baseURL,
            stack: stack,
            depth: depth
        ) {
            return included
        }

        if let dictionary = value as? [String: Any] {
            var resolved: [String: Any] = [:]
            for (key, child) in dictionary {
                resolved[key] = try await resolveLegacyIncludes(
                    in: child,
                    documentRoot: documentRoot,
                    baseURL: baseURL,
                    stack: stack,
                    depth: depth
                )
            }
            return resolved
        }

        if let array = value as? [Any] {
            var resolved: [Any] = []
            for child in array {
                resolved.append(try await resolveLegacyIncludes(
                    in: child,
                    documentRoot: documentRoot,
                    baseURL: baseURL,
                    stack: stack,
                    depth: depth
                ))
            }
            return resolved
        }

        return value
    }

    private func applyingIncludeDirectiveIfPresent(
        in value: Any,
        documentRoot: Any,
        baseURL: URL?,
        stack: Set<String>,
        depth: Int
    ) async throws -> Any? {
        guard depth < Self.maxIncludeDepth else { throw DocumentError.includeDepthExceeded }
        guard var dictionary = value as? [String: Any] else { return nil }
        let includeKey: String
        if dictionary["+"] != nil {
            includeKey = "+"
        } else if dictionary["@"] != nil {
            includeKey = "@"
        } else {
            return nil
        }
        guard let reference = dictionary.removeValue(forKey: includeKey) as? String else { return nil }
        let resolvedReference: (value: Any, baseURL: URL?, stack: Set<String>, documentRoot: Any, isWholeDocument: Bool)
        do {
            resolvedReference = try await resolveIncludeReference(
                reference,
                documentRoot: documentRoot,
                baseURL: baseURL,
                stack: stack
            )
        } catch {
            if includeKey == "@" {
                #if DEBUG
                print("[Jasonette] legacy @ include failed (\(error)); preserving inline value")
                #endif
                return nil
            }
            throw error
        }
        let combined: Any
        if !dictionary.isEmpty, var includedDictionary = resolvedReference.value as? [String: Any] {
            for (key, value) in dictionary {
                includedDictionary[key] = value
            }
            combined = includedDictionary
        } else {
            combined = resolvedReference.value
        }
        let nextDocumentRoot = (!dictionary.isEmpty && resolvedReference.isWholeDocument)
            ? combined
            : resolvedReference.documentRoot
        return try await resolveLegacyIncludes(
            in: combined,
            documentRoot: nextDocumentRoot,
            baseURL: resolvedReference.baseURL ?? baseURL,
            stack: resolvedReference.stack,
            depth: depth + 1
        )
    }

    private func resolveIncludeReference(
        _ reference: String,
        documentRoot: Any,
        baseURL: URL?,
        stack: Set<String>
    ) async throws -> (value: Any, baseURL: URL?, stack: Set<String>, documentRoot: Any, isWholeDocument: Bool) {
        if reference.hasPrefix("$document") {
            let path = String(reference.dropFirst("$document".count))
            return (
                value(at: path, in: documentRoot) ?? NSNull(),
                baseURL,
                stack,
                documentRoot,
                path.trimmingCharacters(in: CharacterSet(charactersIn: ".")).isEmpty
            )
        }

        let (path, urlString) = splitRemoteIncludeReference(reference)
        guard let url = JasonURL.resolve(urlString, against: baseURL, allowedSchemes: Self.allowedSchemes) else {
            throw DocumentError.blockedURL
        }
        let signature = [path ?? "", url.absoluteString].joined(separator: "@")
        guard !stack.contains(signature) else { throw DocumentError.includeCycle }
        var nextStack = stack
        nextStack.insert(signature)
        let loaded = try await loadRawJSONWithMetadata(from: url, validatingRedirects: true)
        let selected = path.flatMap { value(at: $0, in: loaded.value) } ?? loaded.value
        return (selected, loaded.url, nextStack, loaded.value, path == nil)
    }

    private func splitRemoteIncludeReference(_ reference: String) -> (path: String?, url: String) {
        guard let atIndex = reference.firstIndex(of: "@") else { return (nil, reference) }
        let path = String(reference[..<atIndex])
        let url = String(reference[reference.index(after: atIndex)...])
        guard !path.isEmpty, !url.isEmpty else { return (nil, reference) }
        // `items@feed/db.json` means select `items` from the remote JSON. A
        // literal URL may also contain `@` (userinfo/path/query); do not split
        // those as include paths.
        guard !path.contains("://") else { return (nil, reference) }
        return (path, url)
    }

    private func value(at pathReference: Substring, in root: Any) -> Any? {
        value(at: String(pathReference), in: root)
    }

    private func value(at pathReference: String, in root: Any) -> Any? {
        let trimmed = pathReference.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !trimmed.isEmpty else { return root }
        return trimmed.split(separator: ".").reduce(root as Any?) { current, segment in
            guard let current else { return nil }
            if let dictionary = current as? [String: Any] {
                return dictionary[String(segment)]
            }
            if let array = current as? [Any], let index = Int(segment), array.indices.contains(index) {
                return array[index]
            }
            return nil
        }
    }

    /// Decode a document from JSON data.
    public func decode(_ data: Data) throws -> JasonDocument {
        try decoder.decode(JasonDocument.self, from: data)
    }

    /// Decode a document from a JSON string.
    public func decode(_ json: String) throws -> JasonDocument {
        guard let data = json.data(using: .utf8) else {
            throw DocumentError.invalidEncoding
        }
        return try decode(data)
    }

    final class RedirectSchemeValidator: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var blocked = false

        var didBlockRedirect: Bool {
            lock.lock()
            defer { lock.unlock() }
            return blocked
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            guard let scheme = request.url?.scheme?.lowercased(),
                  DocumentLoader.allowedSchemes.contains(scheme) else {
                lock.lock()
                blocked = true
                lock.unlock()
                completionHandler(nil)
                return
            }
            completionHandler(request)
        }
    }

    public enum DocumentError: Error, LocalizedError {
        case httpError(Int)
        case invalidEncoding
        case blockedURL
        case includeCycle
        case includeDepthExceeded

        public var errorDescription: String? {
            switch self {
            case .httpError(let code): return "HTTP error: \(code)"
            case .invalidEncoding: return "Invalid string encoding"
            case .blockedURL: return "URL scheme not allowed"
            case .includeCycle: return "Legacy include cycle detected"
            case .includeDepthExceeded: return "Legacy include depth exceeded"
            }
        }
    }
}
