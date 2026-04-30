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
    /// not depend on custom redirect-delegate callbacks for document loads.
    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// Schemes accepted for document URLs (HTTP fetch). Used by
    /// `DocumentLoader.load`, `ActionDispatcher` `$href`, footer-tab
    /// `.document` / `.web` construction.
    static let allowedSchemes: Set<String> = ["http", "https"]

    /// Schemes accepted for `href.view == "app"` external-app navigation.
    /// Superset of `allowedSchemes`: also opens `mailto:` / `tel:` / `sms:`
    /// via the system. Used by `JasonetteViewModel.handleHref`, the nav
    /// view's `.app` dispatch, and footer-tab `.app` construction.
    static let appSchemes: Set<String> = ["http", "https", "mailto", "tel", "sms"]

    /// Load a document from a URL.
    public func load(from url: URL) async throws -> JasonDocument {
        try await loadWithMetadata(from: url).document
    }

    /// Load a document and return the final response URL. The final URL matters
    /// for resolving authored relative references after HTTP redirects. Redirect
    /// scheme validation is enforced with a request-scoped task delegate, so
    /// custom session redirect delegates are not part of `DocumentLoader`'s
    /// supported extension surface.
    public func loadWithMetadata(from url: URL) async throws -> LoadedDocument {
        guard let scheme = url.scheme?.lowercased(),
              Self.allowedSchemes.contains(scheme) else {
            throw DocumentError.blockedURL
        }
        let redirectDelegate = RedirectSchemeValidator()
        let (data, response) = try await session.data(for: URLRequest(url: url), delegate: redirectDelegate)
        if redirectDelegate.didBlockRedirect {
            throw DocumentError.blockedURL
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DocumentError.httpError(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        let responseURL = response.url ?? url
        guard let responseScheme = responseURL.scheme?.lowercased(),
              Self.allowedSchemes.contains(responseScheme) else {
            throw DocumentError.blockedURL
        }
        return LoadedDocument(document: try decode(data), url: responseURL)
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

    private final class RedirectSchemeValidator: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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

        public var errorDescription: String? {
            switch self {
            case .httpError(let code): return "HTTP error: \(code)"
            case .invalidEncoding: return "Invalid string encoding"
            case .blockedURL: return "URL scheme not allowed"
            }
        }
    }
}
