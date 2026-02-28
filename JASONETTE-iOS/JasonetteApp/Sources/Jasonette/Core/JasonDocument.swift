import Foundation

/// Top-level $jason document.
public struct JasonDocument: Codable, Sendable {
    public let jason: JasonRoot

    enum CodingKeys: String, CodingKey {
        case jason = "$jason"
    }
}

public struct JasonRoot: Codable, Sendable {
    public var head: JasonHead?
    public var body: JasonBody?
}

public struct JasonHead: Codable, Sendable {
    public var title: String?
    public var data: [String: AnyCodable]?
    public var templates: JasonTemplates?
    public var styles: [String: JasonStyle]?
    public var actions: [String: JasonAction]?
}

public struct JasonTemplates: Codable, Sendable {
    public var body: AnyCodable?
}

public struct JasonBody: Codable, Sendable {
    public var background: AnyCodable?
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
    public var header: JasonComponent?
    public var items: [JasonComponent]?
    public var style: JasonStyle?
}

public final class JasonComponent: Codable, @unchecked Sendable {
    public var type: String?
    public var text: String?
    public var url: String?
    public var name: String?
    public var value: AnyCodable?
    public var placeholder: String?
    public var `class`: String?
    public var style: JasonStyle?
    public var components: [JasonComponent]?
    public var href: JasonHref?
    public var action: JasonAction?
    public var keyboard: String?

    enum CodingKeys: String, CodingKey {
        case type, text, url, name, value, placeholder
        case `class`
        case style, components, href, action, keyboard
    }
}

public struct JasonHref: Codable, Sendable {
    public var url: String?
    public var view: String?
    public var transition: String?
    public var fresh: Bool?
    public var preload: AnyCodable?
}

public final class JasonAction: Codable, @unchecked Sendable {
    public var type: String?
    public var options: [String: AnyCodable]?
    public var success: JasonAction?
    public var error: JasonAction?
}

public struct JasonFooter: Codable, Sendable {
    public var tabs: JasonTabs?
    public var input: [String: JasonComponent]?
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

    enum CodingKeys: String, CodingKey {
        case font, size, color, background, padding, width, height, align, spacing
        case paddingLeft = "padding_left"
        case paddingRight = "padding_right"
        case paddingTop = "padding_top"
        case paddingBottom = "padding_bottom"
        case cornerRadius = "corner_radius"
        case borderWidth = "border_width"
        case borderColor = "border_color"
    }
}
