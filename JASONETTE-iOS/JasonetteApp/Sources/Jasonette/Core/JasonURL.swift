import Foundation

/// URL helpers shared by renderer/navigation code.
enum JasonURL {
    /// Resolve a Jasonette URL string against the currently loaded document URL.
    ///
    /// Absolute URLs are returned unchanged. Relative paths are interpreted the
    /// same way a browser resolves links from a document: `icons/home.png`
    /// beside `https://example.com/app/home.json` becomes
    /// `https://example.com/app/icons/home.png`, while `/home` becomes
    /// `https://example.com/home`.
    static func resolve(_ string: String, against baseURL: URL?) -> URL? {
        guard !string.isEmpty else { return nil }
        if let baseURL {
            return URL(string: string, relativeTo: baseURL)?.absoluteURL
        }
        guard let url = URL(string: string), url.scheme != nil else { return nil }
        return url.absoluteURL
    }
}
