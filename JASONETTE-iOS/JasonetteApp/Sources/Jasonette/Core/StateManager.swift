import Foundation
import SwiftUI

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
