import XCTest
@testable import Jasonette

final class StyleModifierTests: XCTestCase {

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

    // MARK: - Helper

    /// Simulates what JasonStyleModifier.resolved does
    private func resolveStyles(className: String?, headStyles: [String: JasonStyle], inline: JasonStyle?) -> JasonStyle {
        var base = JasonStyle()
        if let cls = className {
            let classNames = cls.split(separator: " ").map(String.init)
            for name in classNames {
                if let headStyle = headStyles[name] {
                    base = base.merging(headStyle)
                }
            }
        }
        guard let inline = inline else { return base }
        return base.merging(inline)
    }
}
