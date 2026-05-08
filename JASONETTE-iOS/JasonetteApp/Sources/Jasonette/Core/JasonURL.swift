import Foundation

/// URL helpers shared by renderer/navigation code.
enum JasonURL {
    /// Resolve a Jasonette URL string against the currently loaded document URL.
    ///
    /// Authored URL strings are resolved to absolute URLs. Empty authored URL
    /// strings are treated as unsupported and return nil; use an explicit
    /// document URL for current-page targets. Relative paths are interpreted the
    /// same Foundation/RFC-style way links resolve from a document: `icons/home.png`
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

    /// Resolve an authored URL and keep it only when the resulting absolute URL
    /// uses one of the caller's accepted schemes. Scheme validation intentionally
    /// happens after relative resolution so `/api` is checked as `https://…/api`,
    /// while absolute `file:` / `javascript:` strings stay blocked.
    static func resolve(
        _ string: String,
        against baseURL: URL?,
        allowedSchemes: Set<String>
    ) -> URL? {
        guard let url = resolve(string, against: baseURL),
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else { return nil }
        return url
    }
}
