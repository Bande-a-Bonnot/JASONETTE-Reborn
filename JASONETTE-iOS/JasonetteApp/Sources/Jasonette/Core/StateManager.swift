import Foundation
import SwiftUI

/// Manages Jasonette state: local ($set/$get), cache, global, and session stores.
@MainActor
public final class StateManager: ObservableObject {
    @Published public var local: [String: Any] = [:]
    public var cache: [String: Any] {
        didSet { persistCache() }
    }

    private let cacheKey = "jasonette:cache"
    private let globalKey = "jasonette:global"
    private let sessionKey = "jasonette:session"
    private let defaults: UserDefaults
    private var global: [String: Any]
    private var sessions: [String: [String: Any]]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: cacheKey),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            cache = dict
        } else {
            cache = [:]
        }
        if let data = defaults.data(forKey: globalKey),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            global = dict
        } else {
            global = [:]
        }
        sessions = Self.loadSessions(from: defaults, key: sessionKey)
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

    // MARK: - Bindings for input components

    public func binding(forKey key: String, default defaultValue: String = "") -> Binding<String> {
        Binding<String>(
            get: { self.local[key] as? String ?? defaultValue },
            set: { self.local[key] = $0 }
        )
    }

    public func binding(forKey key: String, default defaultValue: Double = 0) -> Binding<Double> {
        Binding<Double>(
            get: {
                if let d = self.local[key] as? Double { return d }
                if let i = self.local[key] as? Int { return Double(i) }
                return defaultValue
            },
            set: { self.local[key] = $0 }
        )
    }

    public func binding(forKey key: String, default defaultValue: Bool = false) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.local[key] as? Bool ?? defaultValue },
            set: { self.local[key] = $0 }
        )
    }

    // MARK: - Cache ($cache.set / $cache.get / $cache.reset)

    public func cacheSet(_ values: [String: Any]) {
        let candidate = cache.merging(values) { _, new in new }
        guard JSONSerialization.isValidJSONObject(candidate) else {
            _cacheSetFailureHandler("[Jasonette] cacheSet: values contain non-JSON-serializable type — update dropped")
            return
        }
        cache = candidate
    }

    /// Seam for testing: overridden in tests to record violations without crashing.
    /// In debug builds this traps; in release it logs to console.
    var _cacheSetFailureHandler: (String) -> Void = { message in
        #if DEBUG
        assertionFailure(message)
        #else
        print(message)
        #endif
    }

    public func cacheGet() -> [String: Any] {
        cache
    }

    public func cacheReset() {
        cache = [:]
    }

    // MARK: - Global ($global.set / $global.reset)

    @discardableResult
    public func globalSet(_ values: [String: Any]) -> [String: Any] {
        _ = globalGet()
        global.merge(values) { _, new in new }
        persistGlobal()
        return globalGet()
    }

    @discardableResult
    public func globalReset(items: [String]) -> [String: Any] {
        _ = globalGet()
        for item in items { global.removeValue(forKey: item) }
        persistGlobal()
        return globalGet()
    }

    public func globalGet() -> [String: Any] {
        if let data = defaults.data(forKey: globalKey),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            global = dict
        }
        return global
    }

    // MARK: - Session ($session.set / $session.reset)

    public func sessionSet(domain: String, values: [String: Any]) {
        sessions = Self.loadSessions(from: defaults, key: sessionKey)
        sessions[domain.lowercased()] = values
        persistSessions()
    }

    public func sessionReset(domain: String) {
        sessions = Self.loadSessions(from: defaults, key: sessionKey)
        sessions.removeValue(forKey: domain.lowercased())
        persistSessions()
    }

    public func session(forDomain domain: String) -> [String: Any]? {
        sessions = Self.loadSessions(from: defaults, key: sessionKey)
        return sessions[domain.lowercased()]
    }

    // MARK: - Flush (clear local + cache)

    public func flush() {
        local = [:]
        cache = [:]
    }

    // MARK: - Persistence

    private func persistCache() {
        persist(cache, key: cacheKey)
    }

    private func persistGlobal() {
        persist(global, key: globalKey)
    }

    private func persistSessions() {
        persist(sessions, key: sessionKey)
    }

    private func persist(_ value: Any, key: String) {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadSessions(from defaults: UserDefaults, key: String) -> [String: [String: Any]] {
        guard let data = defaults.data(forKey: key),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return raw.reduce(into: [:]) { result, element in
            if let session = element.value as? [String: Any] {
                result[element.key.lowercased()] = session
            }
        }
    }
}
