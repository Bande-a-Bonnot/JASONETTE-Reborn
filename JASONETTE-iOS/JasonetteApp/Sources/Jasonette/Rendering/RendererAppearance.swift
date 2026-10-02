import SwiftUI

/// Numeric channels shared by color rendering and the appearance policy.
struct RendererColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    static let black = RendererColor(red: 0, green: 0, blue: 0)
    static let white = RendererColor(red: 1, green: 1, blue: 1)

    init?(css: String) {
        let value = css.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("#") {
            self.init(hex: value)
        } else if value.hasPrefix("rgb") {
            self.init(cssRGB: value)
        } else {
            return nil
        }
    }

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8,
              let number = UInt64(value, radix: 16) else { return nil }
        let shift = value.count == 8 ? 8 : 0
        self.init(
            red: Double((number >> (16 + shift)) & 0xFF) / 255,
            green: Double((number >> (8 + shift)) & 0xFF) / 255,
            blue: Double((number >> shift) & 0xFF) / 255,
            alpha: shift == 8 ? Double(number & 0xFF) / 255 : 1
        )
    }

    init?(cssRGB: String) {
        let isRGBA = cssRGB.hasPrefix("rgba(")
        let isRGB = cssRGB.hasPrefix("rgb(")
        guard (isRGB || isRGBA), cssRGB.hasSuffix(")") else { return nil }
        let parts = cssRGB.dropFirst(isRGBA ? 5 : 4).dropLast()
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard (isRGB && parts.count == 3) || (isRGBA && parts.count == 4),
              let red = Int(parts[0]), let green = Int(parts[1]), let blue = Int(parts[2]),
              (0...255).contains(red), (0...255).contains(green), (0...255).contains(blue)
        else { return nil }
        let alpha: Double
        if isRGBA {
            guard let value = Double(parts[3]) else { return nil }
            alpha = min(max(value, 0), 1)
        } else {
            alpha = 1
        }
        self.init(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, alpha: alpha)
    }

    func composited(over background: RendererColor) -> RendererColor {
        let outputAlpha = alpha + background.alpha * (1 - alpha)
        guard outputAlpha > 0 else { return self }
        func channel(_ foreground: Double, _ backdrop: Double) -> Double {
            (foreground * alpha + backdrop * background.alpha * (1 - alpha)) / outputAlpha
        }
        return RendererColor(
            red: channel(red, background.red),
            green: channel(green, background.green),
            blue: channel(blue, background.blue),
            alpha: outputAlpha
        )
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    private var relativeLuminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrast(against background: RendererColor) -> Double {
        let displayed = composited(over: background).relativeLuminance
        let backdrop = background.relativeLuminance
        return (max(displayed, backdrop) + 0.05) / (min(displayed, backdrop) + 0.05)
    }

    var contrastingForeground: RendererColor {
        Self.black.contrast(against: self) >= Self.white.contrast(against: self) ? .black : .white
    }
}

struct RendererInputAppearance {
    let fill: RendererColor
    let effectiveBackground: RendererColor
    let foreground: RendererColor
    let placeholder: RendererColor
}

/// Effective rendered surface and inherited authored foreground for a subtree.
struct RendererAppearance {
    let background: RendererColor
    let authoredForeground: RendererColor?

    var scheme: ColorScheme {
        background.contrastingForeground == .black ? .light : .dark
    }

    var foreground: RendererColor {
        authoredForeground ?? background.contrastingForeground
    }

    static func document(body: JasonBody?, systemScheme: ColorScheme) -> RendererAppearance {
        // A selected HTML background replaces the CSS fallback in rendering.
        // Its arbitrary content does not provide a trustworthy solid color.
        let cssBackground: String? = body?.htmlBackground == nil
            ? (body?.background?.string ?? body?.style?.background) : nil
        let background = cssBackground.flatMap { RendererColor(css: $0) }
        let canvas: RendererColor = systemScheme == .dark ? .black : .white
        return RendererAppearance(
            background: background?.composited(over: canvas) ?? canvas,
            authoredForeground: body?.style?.color.flatMap { RendererColor(css: $0) }
        )
    }

    func applying(style: JasonStyle) -> RendererAppearance {
        RendererAppearance(
            background: style.background.flatMap { RendererColor(css: $0) }?.composited(over: background) ?? background,
            authoredForeground: style.color.flatMap { RendererColor(css: $0) } ?? authoredForeground
        )
    }

    func input(style: JasonStyle? = nil) -> RendererInputAppearance {
        let explicitFill = style?.background.flatMap { RendererColor(css: $0) }
        let fill: RendererColor = explicitFill ?? (scheme == .dark ? .black : .white)
        // The component boundary already composited an explicit background.
        let effectiveBackground = explicitFill == nil ? fill : background
        let authored = style?.color.flatMap { RendererColor(css: $0) } ?? authoredForeground
        let primary = authored ?? effectiveBackground.contrastingForeground
        let softened = RendererColor(red: primary.red, green: primary.green, blue: primary.blue, alpha: 0.65)
        let placeholder = authored ?? (softened.contrast(against: effectiveBackground) >= 4.5 ? softened : primary)
        return RendererInputAppearance(
            fill: fill,
            effectiveBackground: effectiveBackground,
            foreground: primary,
            placeholder: placeholder
        )
    }
}

private struct RendererAppearanceKey: EnvironmentKey {
    static let defaultValue: RendererAppearance? = nil
}

extension EnvironmentValues {
    var rendererAppearance: RendererAppearance? {
        get { self[RendererAppearanceKey.self] }
        set { self[RendererAppearanceKey.self] = newValue }
    }
}

struct RendererDocumentAppearanceModifier: ViewModifier {
    let documentBody: JasonBody?
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let appearance = RendererAppearance.document(body: documentBody, systemScheme: systemScheme)
        content
            .foregroundColor(appearance.foreground.color)
            .environment(\.rendererAppearance, appearance)
            .environment(\.colorScheme, appearance.scheme)
    }
}

struct RendererComponentAppearanceModifier: ViewModifier {
    let style: JasonStyle
    @Environment(\.rendererAppearance) private var inherited
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let appearance = (inherited ?? RendererAppearance.document(body: nil, systemScheme: systemScheme))
            .applying(style: style)
        content
            .foregroundColor(appearance.foreground.color)
            .environment(\.rendererAppearance, appearance)
            .environment(\.colorScheme, appearance.scheme)
    }
}

/// Only default fills are painted here. Authored backgrounds are painted once
/// by JasonStyleModifier after authored padding and bounds have been applied.
struct RendererInputSurface: View {
    static let defaultCornerRadius: CGFloat = 6
    let appearance: RendererInputAppearance
    let style: JasonStyle?

    var body: some View {
        let radius = style?.cornerRadius?.cgFloat ?? Self.defaultCornerRadius
        let hasAuthoredBackground = style?.background.flatMap { RendererColor(css: $0) } != nil
        RoundedRectangle(cornerRadius: radius)
            .fill(hasAuthoredBackground ? Color.clear : appearance.fill.color)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(
                        appearance.effectiveBackground.contrastingForeground.color.opacity(0.35),
                        lineWidth: style?.borderWidth == nil ? 1 : 0
                    )
            )
            .allowsHitTesting(false)
    }
}

struct RendererTextInputModifier: ViewModifier {
    let style: JasonStyle?
    @Environment(\.rendererAppearance) private var inherited
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let appearance = (inherited ?? RendererAppearance.document(body: nil, systemScheme: systemScheme))
            .input(style: style)
        content
            .textFieldStyle(.plain)
            .foregroundColor(appearance.foreground.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .background(RendererInputSurface(appearance: appearance, style: style))
            .contentShape(Rectangle())
    }
}
