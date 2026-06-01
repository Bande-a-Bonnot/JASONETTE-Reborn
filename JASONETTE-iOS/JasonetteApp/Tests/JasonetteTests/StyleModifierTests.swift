import XCTest
@testable import Jasonette

final class StyleModifierTests: XCTestCase {

    // MARK: - Helpers

    private func decodeStyle(_ json: [String: Any]) -> JasonStyle {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonStyle.self, from: data)
    }

    // MARK: - Multi-class merging

    func testSingleClassResolution() {
        let headStyles: [String: JasonStyle] = [
            "bold": JasonStyle(font: "bold"),
        ]
        let resolved = resolveStyles(className: "bold", headStyles: headStyles, inline: nil)
        XCTAssertEqual(resolved.font, "bold")
    }

    func testMultiClassMergesInOrder() {
        let headStyles: [String: JasonStyle] = [
            "bold": JasonStyle(font: "bold"),
            "large": JasonStyle(size: AnyCodable(24)),
        ]
        let resolved = resolveStyles(className: "bold large", headStyles: headStyles, inline: nil)
        XCTAssertEqual(resolved.font, "bold")
        XCTAssertEqual(resolved.size?.cgFloat, 24)
    }

    func testMultiClassLaterOverridesEarlier() {
        let headStyles: [String: JasonStyle] = [
            "red": JasonStyle(color: "#FF0000"),
            "blue": JasonStyle(color: "#0000FF"),
        ]
        let resolved = resolveStyles(className: "red blue", headStyles: headStyles, inline: nil)
        XCTAssertEqual(resolved.color, "#0000FF")
    }

    func testInlineOverridesClass() {
        let headStyles: [String: JasonStyle] = [
            "bold": JasonStyle(font: "bold"),
        ]
        let inline = JasonStyle(font: "light")
        let resolved = resolveStyles(className: "bold", headStyles: headStyles, inline: inline)
        XCTAssertEqual(resolved.font, "light")
    }

    func testNoClassNoInline() {
        let resolved = resolveStyles(className: nil, headStyles: [:], inline: nil)
        XCTAssertNil(resolved.font)
        XCTAssertNil(resolved.color)
    }

    func testUnknownClassIgnored() {
        let headStyles: [String: JasonStyle] = [
            "bold": JasonStyle(font: "bold"),
        ]
        let resolved = resolveStyles(className: "bold unknown", headStyles: headStyles, inline: nil)
        XCTAssertEqual(resolved.font, "bold")
    }

    // MARK: - Style merging

    func testMergingPreservesBase() {
        let base = JasonStyle(font: "bold", color: "#FF0000")
        let overlay = JasonStyle(color: "#0000FF")
        let merged = base.merging(overlay)
        XCTAssertEqual(merged.font, "bold")
        XCTAssertEqual(merged.color, "#0000FF")
    }

    func testMergingNilDoesNotOverride() {
        let base = JasonStyle(font: "bold")
        let overlay = JasonStyle()
        let merged = base.merging(overlay)
        XCTAssertEqual(merged.font, "bold")
    }

    func testDynamicLayerInteractionFlagsDecodeAndMerge() {
        let base = JasonStyle(move: AnyCodable("true"))
        let overlay = JasonStyle(resize: AnyCodable(true), rotate: AnyCodable(1))
        let merged = base.merging(overlay)

        XCTAssertTrue(merged.isMoveEnabled)
        XCTAssertTrue(merged.isResizeEnabled)
        XCTAssertTrue(merged.isRotateEnabled)
    }

    // MARK: - withoutSize

    func testWithoutSizeClearsWidthAndHeight() {
        let style = JasonStyle(
            color: "#FF0000",
            background: "#00FF00",
            padding: AnyCodable(8),
            width: AnyCodable(21),
            height: AnyCodable(21),
            opacity: AnyCodable(0.5)
        )
        let stripped = style.withoutSize()
        XCTAssertNil(stripped.width)
        XCTAssertNil(stripped.height)
        XCTAssertEqual(stripped.color, "#FF0000")
        XCTAssertEqual(stripped.background, "#00FF00")
        XCTAssertEqual(stripped.padding?.cgFloat, 8)
        XCTAssertEqual(stripped.opacity?.cgFloat, 0.5)
    }

    func testWithoutSizeIsNonMutating() {
        let style = JasonStyle(width: AnyCodable(24), height: AnyCodable(24))
        _ = style.withoutSize()
        XCTAssertEqual(style.width?.cgFloat, 24)
        XCTAssertEqual(style.height?.cgFloat, 24)
    }

    // MARK: - Positioning fields decoding

    func testDecodingStyleWithPositioningFields() throws {
        let json: [String: Any] = ["top": "10", "left": "20", "bottom": "30", "right": "40"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let style = try JSONDecoder().decode(JasonStyle.self, from: data)
        XCTAssertEqual(style.top?.cgFloat, 10)
        XCTAssertEqual(style.left?.cgFloat, 20)
        XCTAssertEqual(style.bottom?.cgFloat, 30)
        XCTAssertEqual(style.right?.cgFloat, 40)
    }

    func testDecodingStyleWithNumericPositioningFields() throws {
        let json: [String: Any] = ["top": 15, "left": 25]
        let data = try JSONSerialization.data(withJSONObject: json)
        let style = try JSONDecoder().decode(JasonStyle.self, from: data)
        XCTAssertEqual(style.top?.cgFloat, 15)
        XCTAssertEqual(style.left?.cgFloat, 25)
        XCTAssertNil(style.bottom)
        XCTAssertNil(style.right)
    }

    func testDecodingStyleWithoutPositioningFields() throws {
        let json: [String: Any] = ["font": "bold"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let style = try JSONDecoder().decode(JasonStyle.self, from: data)
        XCTAssertNil(style.top)
        XCTAssertNil(style.left)
        XCTAssertNil(style.bottom)
        XCTAssertNil(style.right)
    }

    // MARK: - Positioning fields merging

    func testMergingPositioningFields() {
        let base = JasonStyle(top: AnyCodable(10), left: AnyCodable(20))
        let overlay = JasonStyle(bottom: AnyCodable(30), right: AnyCodable(40))
        let merged = base.merging(overlay)
        XCTAssertEqual(merged.top?.cgFloat, 10)
        XCTAssertEqual(merged.left?.cgFloat, 20)
        XCTAssertEqual(merged.bottom?.cgFloat, 30)
        XCTAssertEqual(merged.right?.cgFloat, 40)
    }

    func testMergingPositioningFieldsInlineOverridesClass() {
        let base = JasonStyle(top: AnyCodable(10), left: AnyCodable(20))
        let overlay = JasonStyle(top: AnyCodable(99))
        let merged = base.merging(overlay)
        XCTAssertEqual(merged.top?.cgFloat, 99)
        XCTAssertEqual(merged.left?.cgFloat, 20)
    }

    func testMergingPositioningFieldsNilDoesNotOverride() {
        let base = JasonStyle(top: AnyCodable(10))
        let overlay = JasonStyle()
        let merged = base.merging(overlay)
        XCTAssertEqual(merged.top?.cgFloat, 10)
        XCTAssertNil(merged.left)
    }

    // MARK: - Opacity decoding

    func testOpacityDecodes() {
        let style = decodeStyle(["opacity": "0.5"])
        XCTAssertEqual(style.opacity?.cgFloat, 0.5)
    }

    func testOpacityZeroDecodes() {
        let style = decodeStyle(["opacity": "0"])
        XCTAssertEqual(style.opacity?.cgFloat, 0)
    }

    func testOpacityOneDecodes() {
        let style = decodeStyle(["opacity": "1"])
        XCTAssertEqual(style.opacity?.cgFloat, 1)
    }

    func testOpacityMerging() {
        let head = JasonStyle(opacity: AnyCodable(0.3))
        let inline = JasonStyle(opacity: AnyCodable(0.8))
        let merged = head.merging(inline)
        XCTAssertEqual(merged.opacity?.cgFloat, 0.8)
    }

    func testOpacityMergingInlineOverridesHead() {
        let headStyles: [String: JasonStyle] = [
            "faded": JasonStyle(opacity: AnyCodable(0.3)),
        ]
        let inline = JasonStyle(opacity: AnyCodable(0.9))
        let resolved = resolveStyles(className: "faded", headStyles: headStyles, inline: inline)
        XCTAssertEqual(resolved.opacity?.cgFloat, 0.9)
    }

    func testOpacityNilWhenAbsent() {
        let style = decodeStyle(["color": "#FF0000"])
        XCTAssertNil(style.opacity)
    }

    // MARK: - Border decoding

    func testBorderFieldsDecode() {
        let style = decodeStyle(["border_width": "2", "border_color": "#000000"])
        XCTAssertEqual(style.borderWidth?.cgFloat, 2)
        XCTAssertEqual(style.borderColor, "#000000")
    }

    func testBorderColorWithoutWidth() {
        let style = decodeStyle(["border_color": "#FF0000"])
        XCTAssertNil(style.borderWidth)
        XCTAssertEqual(style.borderColor, "#FF0000")
    }

    func testBorderWidthWithoutColor() {
        let style = decodeStyle(["border_width": "1"])
        XCTAssertEqual(style.borderWidth?.cgFloat, 1)
        XCTAssertNil(style.borderColor)
    }

    // MARK: - Directional padding decoding

    func testDirectionalPaddingDecodes() {
        let style = decodeStyle(["padding_left": "10", "padding_top": "5"])
        XCTAssertEqual(style.paddingLeft?.cgFloat, 10)
        XCTAssertEqual(style.paddingTop?.cgFloat, 5)
        XCTAssertNil(style.paddingRight)
        XCTAssertNil(style.paddingBottom)
    }

    func testAllDirectionalPaddingDecodes() {
        let style = decodeStyle([
            "padding_left": "10",
            "padding_right": "20",
            "padding_top": "5",
            "padding_bottom": "15",
        ])
        XCTAssertEqual(style.paddingLeft?.cgFloat, 10)
        XCTAssertEqual(style.paddingRight?.cgFloat, 20)
        XCTAssertEqual(style.paddingTop?.cgFloat, 5)
        XCTAssertEqual(style.paddingBottom?.cgFloat, 15)
    }

    func testDirectionalPaddingWithUniform() {
        let style = decodeStyle(["padding": "10", "padding_left": "20"])
        XCTAssertEqual(style.padding?.cgFloat, 10)
        XCTAssertEqual(style.paddingLeft?.cgFloat, 20)
    }

    // MARK: - Alignment decoding

    func testAlignCenterDecodes() {
        let style = decodeStyle(["align": "center"])
        XCTAssertEqual(style.align, "center")
    }

    func testAlignLeftDecodes() {
        let style = decodeStyle(["align": "left"])
        XCTAssertEqual(style.align, "left")
    }

    func testAlignRightDecodes() {
        let style = decodeStyle(["align": "right"])
        XCTAssertEqual(style.align, "right")
    }

    func testAlignNilWhenAbsent() {
        let style = decodeStyle(["color": "#FF0000"])
        XCTAssertNil(style.align)
    }

    // MARK: - Secure text entry decoding

    func testSecureTrueStringDecodesAsSecureTextEntry() {
        let style = decodeStyle(["secure": "true"])
        XCTAssertEqual(style.secure?.string, "true")
        XCTAssertTrue(style.isSecureTextEntry)
    }

    func testSecureFalseStringDecodesAsNonSecureTextEntry() {
        let style = decodeStyle(["secure": "false"])
        XCTAssertFalse(style.isSecureTextEntry)
    }

    func testSecureMergingInlineOverridesClass() {
        let base = JasonStyle(secure: AnyCodable(false))
        let overlay = JasonStyle(secure: AnyCodable("true"))
        let merged = base.merging(overlay)
        XCTAssertTrue(merged.isSecureTextEntry)
    }

    func testSecureMergingNilDoesNotOverride() {
        let base = JasonStyle(secure: AnyCodable(true))
        let overlay = JasonStyle()
        let merged = base.merging(overlay)
        XCTAssertTrue(merged.isSecureTextEntry)
    }

    // MARK: - Map selected annotation decoding

    func testSelectedTrueStringDecodesAsSelectedAnnotation() {
        let style = decodeStyle(["selected": "true"])
        XCTAssertEqual(style.selected?.string, "true")
        XCTAssertTrue(style.isSelectedAnnotation)
    }

    func testSelectedMergingInlineOverridesClass() {
        let base = JasonStyle(selected: AnyCodable(false))
        let overlay = JasonStyle(selected: AnyCodable("true"))
        let merged = base.merging(overlay)
        XCTAssertTrue(merged.isSelectedAnnotation)
    }

    // MARK: - Regression: no new properties unchanged behavior

    func testNoNewPropertiesIdenticalBehavior() {
        let style = JasonStyle(font: "bold", color: "#FF0000")
        let merged = style.merging(JasonStyle())
        XCTAssertEqual(merged.font, "bold")
        XCTAssertEqual(merged.color, "#FF0000")
        XCTAssertNil(merged.opacity)
        XCTAssertNil(merged.borderWidth)
        XCTAssertNil(merged.borderColor)
        XCTAssertNil(merged.paddingLeft)
        XCTAssertNil(merged.paddingRight)
        XCTAssertNil(merged.paddingTop)
        XCTAssertNil(merged.paddingBottom)
        XCTAssertNil(merged.align)
    }

    // MARK: - Helper

    /// Delegates to the centralized `JasonStyle.resolve` so these tests
    /// exercise the real implementation used by JasonStyleModifier and views.
    private func resolveStyles(className: String?, headStyles: [String: JasonStyle], inline: JasonStyle?) -> JasonStyle {
        JasonStyle.resolve(className: className, inline: inline, headStyles: headStyles)
    }
}
