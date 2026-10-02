import XCTest
import SwiftUI
@testable import Jasonette

final class RendererAppearanceTests: XCTestCase {
    private func body(_ json: [String: Any]) throws -> JasonBody {
        try JSONDecoder().decode(JasonBody.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func fixture(_ path: String) throws -> JasonDocument {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        return try JSONDecoder().decode(JasonDocument.self, from: Data(contentsOf: root.appendingPathComponent(path)))
    }

    /// Independent measurement of the final displayed colors, not the policy's own result.
    private func contrast(_ foreground: RendererColor, _ background: RendererColor) -> Double {
        func luminance(_ color: RendererColor) -> Double {
            func linear(_ value: Double) -> Double {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
        }
        let displayed = RendererColor(
            red: foreground.red * foreground.alpha + background.red * (1 - foreground.alpha),
            green: foreground.green * foreground.alpha + background.green * (1 - foreground.alpha),
            blue: foreground.blue * foreground.alpha + background.blue * (1 - foreground.alpha)
        )
        let a = luminance(displayed), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    func testActualTextfieldFixtureHeadingAndInputsRemainReadableInBothSchemes() throws {
        let document = try fixture("Jasonpedia/view/component/textfield/index.json")
        let section = try XCTUnwrap(document.jason.body?.sections?.first)
        let heading = try XCTUnwrap(section.header)
        let row = try XCTUnwrap(section.items?.first)
        let field = try XCTUnwrap(row.components?.first)
        let styles = document.jason.head?.styles ?? [:]
        for scheme in [ColorScheme.light, .dark] {
            let context = RendererAppearance.document(body: document.jason.body, systemScheme: scheme)
            let headingContext = context.applying(style: JasonStyle.resolve(for: heading, headStyles: styles))
            XCTAssertEqual(headingContext.foreground, .black)
            XCTAssertGreaterThanOrEqual(contrast(headingContext.foreground, headingContext.background), 4.5)
            let fieldStyle = JasonStyle.resolve(for: field, headStyles: styles)
            let input = context.applying(style: JasonStyle.resolve(for: row, headStyles: styles))
                .applying(style: fieldStyle).input(style: fieldStyle)
            XCTAssertEqual(input.fill, .white)
            XCTAssertEqual(input.foreground, .black)
            XCTAssertGreaterThanOrEqual(contrast(input.placeholder, input.effectiveBackground), 4.5)
        }
    }

    func testActualActionFixtureLabelsAndHeadersRemainReadableWhileBodyKeepsAuthoredWhite() throws {
        let document = try fixture("Jasonpedia/action/index.json")
        let documentBody = try XCTUnwrap(document.jason.body)
        let sections = try XCTUnwrap(documentBody.sections)
        let styles = document.jason.head?.styles ?? [:]
        let headers = try sections.map { try XCTUnwrap($0.header) }
        let cells = sections.flatMap { $0.items ?? [] }
        XCTAssertEqual(headers.count, 9)
        XCTAssertEqual(cells.count, 19)

        for scheme in [ColorScheme.light, .dark] {
            let context = RendererAppearance.document(body: documentBody, systemScheme: scheme)
            XCTAssertEqual(context.background, RendererColor(css: "#8bb92d"))
            XCTAssertEqual(context.authoredForeground, .white)
            XCTAssertEqual(context.foreground, .white)

            // Section headers and cells each inherit directly from the body,
            // then resolve their own classes and inline styles in ComponentView.
            for label in headers + cells {
                XCTAssertEqual(label.type, "label")
                let style = JasonStyle.resolve(for: label, headStyles: styles)
                let appearance = context.applying(style: style)
                XCTAssertGreaterThanOrEqual(
                    contrast(appearance.foreground, appearance.background),
                    4.5,
                    "\(scheme): \(label.text ?? "Unnamed Action label")"
                )
            }
        }
    }

    func testBodyOnlyLightBackgroundDefaultsToDarkTextInSystemDark() throws {
        let context = RendererAppearance.document(body: try body(["style": ["background": "#f5f5f5"]]), systemScheme: .dark)
        XCTAssertEqual(context.applying(style: JasonStyle()).foreground, .black)
        XCTAssertEqual(context.scheme, .light)
    }

    func testDarkBodyDefaultsToLightTextInSystemLight() throws {
        let context = RendererAppearance.document(body: try body(["style": ["background": "#121212"]]), systemScheme: .light)
        XCTAssertEqual(context.foreground, .white)
        XCTAssertEqual(context.scheme, .dark)
    }

    func testNestedSurfacesOverrideContextInBothDirections() throws {
        let base = RendererAppearance.document(body: try body(["style": ["background": "#ffffff"]]), systemScheme: .dark)
        let dark = base.applying(style: JasonStyle(background: "#111111"))
        let light = dark.applying(style: JasonStyle(background: "#f5f5f5"))
        XCTAssertEqual(dark.foreground, .white)
        XCTAssertEqual(dark.applying(style: JasonStyle()).scheme, .dark)
        XCTAssertEqual(light.foreground, .black)
        XCTAssertEqual(light.applying(style: JasonStyle()).scheme, .light)
    }

    func testAuthoredForegroundIsInheritedAcrossBackgroundChangesAndChildCanOverride() throws {
        let authored = try XCTUnwrap(RendererColor(css: "rgba(10,20,30,0.7)"))
        let base = RendererAppearance.document(body: try body(["style": ["background": "#ffffff", "color": "rgba(10,20,30,0.7)"]]), systemScheme: .dark)
        let child = base.applying(style: JasonStyle(background: "#000000"))
        XCTAssertEqual(child.foreground, authored)
        XCTAssertEqual(child.input().foreground, authored)
        XCTAssertEqual(child.input().placeholder, authored)
        let overridden = child.applying(style: JasonStyle(color: "#ff0000"))
        XCTAssertEqual(overridden.foreground, RendererColor(red: 1, green: 0, blue: 0))
    }

    func testClassAndInlineBackgroundAndForegroundPrecedence() throws {
        let style = JasonStyle.resolve(
            className: "dark light",
            inline: JasonStyle(color: "#123456"),
            headStyles: ["dark": JasonStyle(color: "#ffffff", background: "#111111"), "light": JasonStyle(background: "#ffffff")]
        )
        for scheme in [ColorScheme.light, .dark] {
            let context = RendererAppearance.document(body: nil, systemScheme: scheme).applying(style: style)
            XCTAssertEqual(context.scheme, .light)
            XCTAssertEqual(context.background, .white)
            XCTAssertEqual(context.foreground, RendererColor(css: "#123456"))
        }
    }

    func testUnspecifiedAndUnsupportedBodyBackgroundsFollowSystemAppearance() throws {
        for background in ["", "red", "#bad", "https://example.com/background.png"] {
            for scheme in [ColorScheme.light, .dark] {
                let context = RendererAppearance.document(body: try body(["style": ["background": background]]), systemScheme: scheme)
                XCTAssertEqual(context.scheme, scheme)
                XCTAssertEqual(context.foreground, scheme == .dark ? .white : .black)
            }
        }
    }

    func testInvalidAndTransparentChildBackgroundsPreserveInheritedContext() throws {
        let base = RendererAppearance.document(body: try body(["style": ["background": "#111111"]]), systemScheme: .light)
        for background in ["rgba(255,255,255,0)", "#ffffff00", "#bad", "https://example.com/bg.jpg"] {
            let child = base.applying(style: JasonStyle(background: background))
            XCTAssertEqual(child.background, base.background)
            XCTAssertEqual(child.foreground, base.foreground)
            XCTAssertEqual(child.scheme, base.scheme)
        }
    }

    func testTranslucentBackgroundUsesCompositeRatherThanSourceColor() throws {
        let dark = RendererAppearance.document(body: try body(["style": ["background": "#000000"]]), systemScheme: .dark)
        let faintWhite = dark.applying(style: JasonStyle(background: "rgba(255,255,255,0.1)"))
        XCTAssertEqual(faintWhite.background.red, 0.1, accuracy: 0.0001)
        XCTAssertEqual(faintWhite.foreground, .white)
        let strongWhite = dark.applying(style: JasonStyle(background: "rgba(255,255,255,0.9)"))
        XCTAssertEqual(strongWhite.background.red, 0.9, accuracy: 0.0001)
        XCTAssertEqual(strongWhite.foreground, .black)
        XCTAssertEqual(strongWhite.scheme, .light)
        let light = RendererAppearance.document(body: try body(["style": ["background": "#ffffff"]]), systemScheme: .light)
        let strongBlack = light.applying(style: JasonStyle(background: "rgba(0,0,0,0.9)"))
        XCTAssertEqual(strongBlack.foreground, .white)
        XCTAssertEqual(strongBlack.scheme, .dark)
    }

    func testBodyBackgroundStringRetainsExistingPrecedence() throws {
        let context = RendererAppearance.document(body: try body(["background": "#000000", "style": ["background": "#ffffff"]]), systemScheme: .light)
        XCTAssertEqual(context.background, .black)
        XCTAssertEqual(context.foreground, .white)
    }

    func testCanonicalHTMLBackgroundIgnoresDiscardedStyleBackgroundInBothSchemes() throws {
        for source in [
            ["type": "html", "text": "<html style='background:white'>HTML</html>"],
            ["type": "html", "url": "https://example.com/background.html"]
        ] {
            for scheme in [ColorScheme.light, .dark] {
                let documentBody = try body([
                    "background": source,
                    "style": ["background": scheme == .light ? "#000000" : "#ffffff"]
                ])
                XCTAssertNotNil(documentBody.htmlBackground)
                let context = RendererAppearance.document(body: documentBody, systemScheme: scheme)
                XCTAssertEqual(context.background, scheme == .light ? .white : .black)
                XCTAssertEqual(context.foreground, scheme == .light ? .black : .white)
                XCTAssertEqual(context.scheme, scheme)
            }
        }
    }

    func testInvalidHTMLBackgroundRetainsStyleBackgroundFallback() throws {
        let invalidSources: [[String: Any]] = [
            ["type": "html"],
            ["type": "html", "text": 42],
            ["type": "html", "url": false],
            ["type": "image", "text": "not an HTML background"]
        ]
        for source in invalidSources {
            let documentBody = try body(["background": source, "style": ["background": "#111111"]])
            XCTAssertNil(documentBody.htmlBackground)
            for scheme in [ColorScheme.light, .dark] {
                let context = RendererAppearance.document(body: documentBody, systemScheme: scheme)
                XCTAssertEqual(context.background, RendererColor(css: "#111111"))
                XCTAssertEqual(context.foreground, .white)
                XCTAssertEqual(context.scheme, .dark)
            }
        }
    }

    func testHTMLBackgroundPreservesExplicitBodyForeground() throws {
        let documentBody = try body([
            "background": ["type": "html", "text": "<p>Background</p>"],
            "style": ["background": "#000000", "color": "#123456"]
        ])
        for scheme in [ColorScheme.light, .dark] {
            let context = RendererAppearance.document(body: documentBody, systemScheme: scheme)
            XCTAssertEqual(context.foreground, RendererColor(css: "#123456"))
        }
    }

    func testUnstyledTabTintPreservesSelectedAccentAndUnselectedSecondary() {
        XCTAssertEqual(FooterTabAppearance.tint(style: JasonStyle(), isSelected: true), Color.accentColor)
        XCTAssertEqual(FooterTabAppearance.tint(style: JasonStyle(), isSelected: false), Color.secondary)
        XCTAssertEqual(FooterTabAppearance.tint(style: JasonStyle(color: "invalid"), isSelected: true), Color.accentColor)
        XCTAssertEqual(FooterTabAppearance.tint(style: JasonStyle(color: "invalid"), isSelected: false), Color.secondary)
    }

    func testAuthoredTabTintPreservesColorAndUnselectedDimming() throws {
        let style = JasonStyle(color: "rgba(10,20,30,0.7)")
        let authored = try XCTUnwrap(Color(css: "rgba(10,20,30,0.7)"))
        XCTAssertEqual(FooterTabAppearance.tint(style: style, isSelected: true), authored)
        XCTAssertEqual(FooterTabAppearance.tint(style: style, isSelected: false), authored.opacity(0.55))
        let resolved = JasonStyle.resolve(
            className: "red",
            inline: JasonStyle(color: "#123456"),
            headStyles: ["red": JasonStyle(color: "#ff0000")]
        )
        XCTAssertEqual(FooterTabAppearance.tint(style: resolved, isSelected: true), Color(css: "#123456"))
    }

    func testDefaultControlFillMatchesAuthoredSurfaceAppearance() throws {
        for scheme in [ColorScheme.light, .dark] {
            let light = RendererAppearance.document(body: try body(["style": ["background": "#f5f5f5"]]), systemScheme: scheme).input()
            let dark = RendererAppearance.document(body: try body(["style": ["background": "#111111"]]), systemScheme: scheme).input()
            XCTAssertEqual(light.fill, .white)
            XCTAssertEqual(light.foreground, .black)
            XCTAssertEqual(dark.fill, .black)
            XCTAssertEqual(dark.foreground, .white)
        }
    }

    func testDefaultInputForegroundAndPlaceholderMeetContrastTargetOnColoredSurfaces() throws {
        for background in ["#ffffff", "#000000", "#777777", "#ff0000", "#336699"] {
            for scheme in [ColorScheme.light, .dark] {
                let style = JasonStyle(background: background)
                let input = RendererAppearance.document(body: nil, systemScheme: scheme).applying(style: style).input(style: style)
                XCTAssertGreaterThanOrEqual(contrast(input.foreground, input.effectiveBackground), 4.5, background)
                XCTAssertGreaterThanOrEqual(contrast(input.placeholder, input.effectiveBackground), 4.5, background)
            }
        }
    }

    func testExplicitInputFillAndForegroundArePreservedIncludingAlpha() throws {
        let style = JasonStyle(color: "rgba(10,20,30,0.7)", background: "#11223380")
        for scheme in [ColorScheme.light, .dark] {
            let base = RendererAppearance.document(body: try body(["style": ["background": "#ffffff"]]), systemScheme: scheme)
            let context = base.applying(style: style)
            let input = context.input(style: style)
            XCTAssertEqual(input.fill, RendererColor(css: "#11223380"))
            XCTAssertEqual(input.foreground, RendererColor(css: "rgba(10,20,30,0.7)"))
            XCTAssertEqual(input.placeholder, input.foreground)
            XCTAssertEqual(input.effectiveBackground, context.background)
        }
    }

    func testActualTextareaFixtureWhiteFillHasReadablePromptAndEnteredTextInDark() throws {
        let document = try fixture("Jasonpedia/view/component/textarea/index.json")
        let row = try XCTUnwrap(document.jason.body?.sections?.first?.items?.first)
        let textarea = try XCTUnwrap(row.components?.first)
        let styles = document.jason.head?.styles ?? [:]
        let style = JasonStyle.resolve(for: textarea, headStyles: styles)
        let input = RendererAppearance.document(body: document.jason.body, systemScheme: .dark)
            .applying(style: JasonStyle.resolve(for: row, headStyles: styles))
            .applying(style: style).input(style: style)
        XCTAssertEqual(input.fill, .white)
        XCTAssertEqual(input.foreground, .black)
        XCTAssertGreaterThanOrEqual(contrast(input.placeholder, input.effectiveBackground), 4.5)
    }
}
