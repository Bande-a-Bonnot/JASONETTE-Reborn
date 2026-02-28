import Foundation

/// Manages Jasonette state: local ($set/$get), cache (UserDefaults).
@MainActor
public final class StateManager: ObservableObject {
    @Published public var local: [String: Any] = [:]
    public var cache: [String: Any] {
        didSet { persistCache() }
    }

    private let cacheKey = "jasonette:cache"

    public init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            cache = dict
        } else {
            cache = [:]
        }
    }

    // MARK: - Local state ($set / $get)

    public func set(_ values: [String: Any]) {
        for (key, value) in values {
            local[key] = value
        }
    }

    public func get() -> [String: Any] {
        local
    }

    // MARK: - Cache ($cache.set / $cache.get / $cache.reset)

    public func cacheSet(_ values: [String: Any]) {
        for (key, value) in values {
            cache[key] = value
        }
    }

    public func cacheGet() -> [String: Any] {
        cache
    }

    public func cacheReset() {
        cache = [:]
    }

    // MARK: - Flush (clear everything)

    public func flush() {
        local = [:]
        cache = [:]
    }

    // MARK: - Persistence

    private func persistCache() {
        if let data = try? JSONSerialization.data(withJSONObject: cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
