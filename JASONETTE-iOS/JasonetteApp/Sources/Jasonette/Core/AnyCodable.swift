import Foundation

/// Type-erased Codable wrapper for dynamic JSON values.
public struct AnyCodable: Codable, Sendable, Equatable, Hashable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    // MARK: - Convenience accessors

    public var string: String? { value as? String }
    public var int: Int? { value as? Int }
    public var double: Double? { value as? Double }
    public var bool: Bool? { value as? Bool }
    public var array: [AnyCodable]? { value as? [AnyCodable] }
    public var dictionary: [String: AnyCodable]? { value as? [String: AnyCodable] }

    public var cgFloat: CGFloat? {
        if let d = value as? Double { return CGFloat(d) }
        if let i = value as? Int { return CGFloat(i) }
        if let s = value as? String, let d = Double(s) { return CGFloat(d) }
        return nil
    }

    // MARK: - Equatable

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let l as String, let r as String): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as Bool, let r as Bool): return l == r
        case (is NSNull, is NSNull): return true
        default: return false
        }
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        switch value {
        case let v as String: hasher.combine(v)
        case let v as Int: hasher.combine(v)
        case let v as Double: hasher.combine(v)
        case let v as Bool: hasher.combine(v)
        default: hasher.combine(0)
        }
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let v = try? container.decode(Bool.self) {
            value = v
        } else if let v = try? container.decode(Int.self) {
            value = v
        } else if let v = try? container.decode(Double.self) {
            value = v
        } else if let v = try? container.decode(String.self) {
            value = v
        } else if let v = try? container.decode([AnyCodable].self) {
            value = v
        } else if let v = try? container.decode([String: AnyCodable].self) {
            value = v
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let v as Bool:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        case let v as String:
            try container.encode(v)
        case let v as [AnyCodable]:
            try container.encode(v)
        case let v as [String: AnyCodable]:
            try container.encode(v)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported value type"
                )
            )
        }
    }
}
