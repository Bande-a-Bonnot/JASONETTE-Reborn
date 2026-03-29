import SwiftUI

/// Applies Jasonette style properties to any SwiftUI view.
struct JasonStyleModifier: ViewModifier {
    let style: JasonStyle?
    let headStyles: [String: JasonStyle]
    let className: String?

    func body(content: Content) -> some View {
        content
            .applyFont(resolved)
            .applyColors(resolved)
            .applySpacing(resolved)
            .applyBorder(resolved)
            .applySize(resolved)
    }

    /// Merge head styles (from class, space-separated) with inline style. Inline wins.
    private var resolved: JasonStyle {
        var base = JasonStyle()
        if let cls = className {
            let classNames = cls.split(separator: " ").map(String.init)
            for name in classNames {
                if let headStyle = headStyles[name] {
                    base = base.merging(headStyle)
                }
            }
        }
        guard let inline = style else { return base }
        return base.merging(inline)
    }
}

// MARK: - Style application extensions

private extension View {
    @ViewBuilder
    func applyFont(_ style: JasonStyle) -> some View {
        let fontSize = style.size?.cgFloat ?? 14
        let weight = fontWeight(from: style.font)
        self
            .font(.system(size: fontSize, weight: weight))
    }

    @ViewBuilder
    func applyColors(_ style: JasonStyle) -> some View {
        let fg = style.color.flatMap { Color(css: $0) }
        let bg = style.background.flatMap { Color(css: $0) }
        if let fg, let bg {
            self.foregroundColor(fg).background(bg)
        } else if let fg {
            self.foregroundColor(fg)
        } else if let bg {
            self.background(bg)
        } else {
            self
        }
    }

    @ViewBuilder
    func applySpacing(_ style: JasonStyle) -> some View {
        let p = style.padding?.cgFloat ?? 0
        self.padding(p)
    }

    @ViewBuilder
    func applyBorder(_ style: JasonStyle) -> some View {
        if let radius = style.cornerRadius?.cgFloat {
            self.clipShape(RoundedRectangle(cornerRadius: radius))
        } else {
            self
        }
    }

    @ViewBuilder
    func applySize(_ style: JasonStyle) -> some View {
        let w = style.width?.cgFloat
        let h = style.height?.cgFloat
        if w != nil || h != nil {
            self.frame(width: w, height: h)
        } else {
            self
        }
    }

    func fontWeight(from font: String?) -> Font.Weight {
        switch font {
        case "bold": return .bold
        case "light": return .light
        default: return .regular
        }
    }
}

// MARK: - JasonStyle merge + init helpers

extension JasonStyle {
    /// Merge another style on top, non-nil values win.
    func merging(_ other: JasonStyle) -> JasonStyle {
        JasonStyle(
            font: other.font ?? self.font,
            size: other.size ?? self.size,
            color: other.color ?? self.color,
            background: other.background ?? self.background,
            padding: other.padding ?? self.padding,
            paddingLeft: other.paddingLeft ?? self.paddingLeft,
            paddingRight: other.paddingRight ?? self.paddingRight,
            paddingTop: other.paddingTop ?? self.paddingTop,
            paddingBottom: other.paddingBottom ?? self.paddingBottom,
            width: other.width ?? self.width,
            height: other.height ?? self.height,
            cornerRadius: other.cornerRadius ?? self.cornerRadius,
            borderWidth: other.borderWidth ?? self.borderWidth,
            borderColor: other.borderColor ?? self.borderColor,
            align: other.align ?? self.align,
            spacing: other.spacing ?? self.spacing,
            top: other.top ?? self.top,
            left: other.left ?? self.left,
            bottom: other.bottom ?? self.bottom,
            right: other.right ?? self.right
        )
    }
}

// MARK: - Color parsing (hex, rgb, rgba)

extension Color {
    /// Unified CSS color parser: dispatches on prefix. Normalizes once here.
    init?(css: String) {
        let s = css.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("#") {
            self.init(hex: s)
        } else if s.hasPrefix("rgb") {
            self.init(cssRGB: s)
        } else {
            return nil
        }
    }

    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }

        guard h.count == 6 || h.count == 8 else { return nil }
        guard let value = UInt64(h, radix: 16) else { return nil }

        if h.count == 6 {
            let r = Double((value >> 16) & 0xFF) / 255
            let g = Double((value >> 8) & 0xFF) / 255
            let b = Double(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b)
        } else {
            let r = Double((value >> 24) & 0xFF) / 255
            let g = Double((value >> 16) & 0xFF) / 255
            let b = Double((value >> 8) & 0xFF) / 255
            let a = Double(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b, opacity: a)
        }
    }

    /// Parses `rgb(r,g,b)` and `rgba(r,g,b,a)`. Input assumed already lowercased by css:.
    init?(cssRGB: String) {
        let s = cssRGB
        let isRGBA = s.hasPrefix("rgba(")
        let isRGB = s.hasPrefix("rgb(")
        guard (isRGB || isRGBA), s.hasSuffix(")") else { return nil }
        let prefix = isRGBA ? 5 : 4
        let inner = s.dropFirst(prefix).dropLast()
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard (isRGB && parts.count == 3) || (isRGBA && parts.count == 4),
              let r = Int(parts[0]), let g = Int(parts[1]), let b = Int(parts[2]),
              (0...255).contains(r), (0...255).contains(g), (0...255).contains(b)
        else { return nil }
        if isRGBA {
            guard let a = Double(parts[3]) else { return nil }
            let clamped = min(max(a, 0), 1)
            self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: clamped)
        } else {
            self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
    }
}
