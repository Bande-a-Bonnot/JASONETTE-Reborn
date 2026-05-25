import CryptoKit
import Foundation

public extension JasonAction {
    /// Content-derived, process-stable hash for action identity.
    ///
    /// Used by tab canonical keys so action-only footer tabs dedupe by JSON
    /// content instead of by the Swift object identity of a decoded instance.
    var stableHash: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(self)) ?? fallbackCanonicalData
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private var fallbackCanonicalData: Data {
        let fallback = "type=\(type ?? "");unencodable=true"
        return Data(fallback.utf8)
    }
}
