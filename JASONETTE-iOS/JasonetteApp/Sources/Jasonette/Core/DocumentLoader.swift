import Foundation

/// Loads and decodes $jason documents from URLs or local data.
public final class DocumentLoader: Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// Load a document from a URL.
    public func load(from url: URL) async throws -> JasonDocument {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DocumentError.httpError(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        return try decode(data)
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

    public enum DocumentError: Error, LocalizedError {
        case httpError(Int)
        case invalidEncoding

        public var errorDescription: String? {
            switch self {
            case .httpError(let code): return "HTTP error: \(code)"
            case .invalidEncoding: return "Invalid string encoding"
            }
        }
    }
}
