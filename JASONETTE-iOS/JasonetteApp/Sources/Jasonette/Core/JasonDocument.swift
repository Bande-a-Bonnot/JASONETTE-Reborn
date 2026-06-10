import Foundation

/// Top-level $jason document.
public struct JasonDocument: Codable, Sendable {
    public let jason: JasonRoot

    enum CodingKeys: String, CodingKey {
        case jason = "$jason"
    }

    public init(jason: JasonRoot) {
        self.jason = jason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jason = try container.decode(JasonRoot.self, forKey: .jason)
    }
}

public struct JasonRoot: Codable, Sendable {
    public var head: JasonHead?
    public var body: JasonBody?

    public init(head: JasonHead? = nil, body: JasonBody? = nil) {
        self.head = head
        self.body = body
    }
}

public struct JasonHead: Codable, Sendable {
    public var title: String?
    public var data: [String: AnyCodable]?
    public var templates: JasonTemplates?
    public var styles: [String: JasonStyle]?
    public var actions: [String: JasonAction]?
}

public struct JasonTemplates: Codable, Sendable {
    private var storage: [String: AnyCodable] = [:]

    public subscript(name: String) -> AnyCodable? {
        get { storage[name] }
        set { storage[name] = newValue }
    }

    public var body: AnyCodable? { storage["body"] }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        storage = try container.decode([String: AnyCodable].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }
}

public struct JasonBody: Codable, Sendable {
    public var background: AnyCodable?
    public var style: JasonStyle?
    public var header: JasonHeader?
    public var sections: [JasonSection]?
    public var layers: [JasonComponent]?
    public var footer: JasonFooter?
}

public struct JasonHeader: Codable, Sendable {
    public var title: String?
    public var menu: JasonComponent?
    public var style: JasonStyle?
}

public struct JasonSection: Codable, Sendable {
    public var type: String?
    public var header: JasonComponent?
    public var items: [JasonComponent]?
    public var style: JasonStyle?
}

public final class JasonComponent: Codable, @unchecked Sendable {
    public var type: String?
    public var text: String?
    public var url: String?
    public var image: String?
    public var name: String?
    public var value: AnyCodable?
    public var placeholder: String?
    public var `class`: String?
    public var style: JasonStyle?
    public var components: [JasonComponent]?
    public var href: JasonHref?
    public var action: JasonAction?
    public var keyboard: String?
    public var badge: String?
    public var css: String?
    public var region: JasonMapRegion?
    public var pins: [JasonMapPin]?

    /// Returns the image URL, preferring `url` over `image` (footer input uses `image` key).
    public var imageURL: String? { url ?? image }

    enum CodingKeys: String, CodingKey {
        case type, text, url, image, name, value, placeholder
        case `class`
        case style, components, href, action, keyboard, badge, css, region, pins
    }
}

public struct JasonMapRegion: Codable, Sendable {
    public var coord: String?
    public var width: AnyCodable?
    public var height: AnyCodable?
}

public struct JasonMapPin: Codable, Sendable {
    public var coord: String?
    public var title: String?
    public var description: String?
    public var style: JasonStyle?
}

public struct JasonHref: Codable, Sendable {
    public var url: String?
    public var view: String?
    public var transition: String?
    public var fresh: Bool?
    public var preload: AnyCodable?
    public var options: [String: AnyCodable]?
}

public final class JasonAction: Codable, @unchecked Sendable {
    public var type: String?
    public var trigger: String?
    public var options: [String: AnyCodable]?
    public var rawOptions: AnyCodable?
    public var success: JasonAction?
    public var error: JasonAction?
    public var successActions: [JasonAction]?
    public var errorActions: [JasonAction]?

    enum CodingKeys: String, CodingKey {
        case type, trigger, options, success, error
    }

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        trigger = try container.decodeIfPresent(String.self, forKey: .trigger)
        rawOptions = try container.decodeIfPresent(AnyCodable.self, forKey: .options)
        options = rawOptions?.dictionary
        successActions = try Self.decodeActionList(from: container, forKey: .success)
        success = successActions?.first
        errorActions = try Self.decodeActionList(from: container, forKey: .error)
        error = errorActions?.first
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(trigger, forKey: .trigger)
        if let rawOptions {
            try container.encode(rawOptions, forKey: .options)
        } else {
            try container.encodeIfPresent(options, forKey: .options)
        }
        try Self.encodeActionList(successActions ?? success.map { [$0] }, to: &container, forKey: .success)
        try Self.encodeActionList(errorActions ?? error.map { [$0] }, to: &container, forKey: .error)
    }

    private static func decodeActionList(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> [JasonAction]? {
        if let action = try? container.decode(JasonAction.self, forKey: key) {
            return [action]
        }
        if let actions = try? container.decode([JasonAction].self, forKey: key) {
            return actions
        }
        return nil
    }

    private static func encodeActionList(
        _ actions: [JasonAction]?,
        to container: inout KeyedEncodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws {
        guard let actions, !actions.isEmpty else { return }
        if actions.count == 1 {
            try container.encode(actions[0], forKey: key)
        } else {
            try container.encode(actions, forKey: key)
        }
    }
}

public struct JasonFooter: Codable, Sendable {
    public var tabs: JasonTabs?
    public var input: JasonFooterInput?
}

public struct JasonFooterInput: Codable, Sendable {
    public var name: String?
    public var placeholder: String?
    public var left: JasonComponent?
    public var right: JasonComponent?
}

public struct JasonTabs: Codable, Sendable {
    public var items: [JasonComponent]?
    public var style: JasonStyle?
}

public struct JasonStyle: Codable, Sendable {
    public var font: String?
    public var size: AnyCodable?
    public var color: String?
    public var background: String?
    public var padding: AnyCodable?
    public var paddingLeft: AnyCodable?
    public var paddingRight: AnyCodable?
    public var paddingTop: AnyCodable?
    public var paddingBottom: AnyCodable?
    public var width: AnyCodable?
    public var height: AnyCodable?
    public var cornerRadius: AnyCodable?
    public var borderWidth: AnyCodable?
    public var borderColor: String?
    public var align: String?
    public var spacing: AnyCodable?
    public var top: AnyCodable?
    public var left: AnyCodable?
    public var bottom: AnyCodable?
    public var right: AnyCodable?
    public var opacity: AnyCodable?
    public var secure: AnyCodable?
    public var selected: AnyCodable?
    public var move: AnyCodable?
    public var resize: AnyCodable?
    public var rotate: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case font, size, color, background, padding, width, height, align, spacing, opacity, secure, selected
        case move, resize, rotate
        case top, left, bottom, right
        case paddingLeft = "padding_left"
        case paddingRight = "padding_right"
        case paddingTop = "padding_top"
        case paddingBottom = "padding_bottom"
        case cornerRadius = "corner_radius"
        case borderWidth = "border_width"
        case borderColor = "border_color"
    }
}
