import XCTest
import SwiftUI
@testable import Jasonette

final class ColorParsingTests: XCTestCase {

    func testNumericHexChannelsPreserveAlpha() throws {
        let color = try XCTUnwrap(RendererColor(css: "#12345680"))
        XCTAssertEqual(color.red, 18.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(color.green, 52.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(color.blue, 86.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(color.alpha, 128.0 / 255, accuracy: 0.0001)
    }

    func testNumericRGBChannelsAndAlphaCompatibility() throws {
        let color = try XCTUnwrap(RendererColor(css: " RGBA(10, 20, 30, 0.25) "))
        XCTAssertEqual(color.red, 10.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(color.green, 20.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(color.blue, 30.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(color.alpha, 0.25)
        XCTAssertEqual(RendererColor(css: "rgba(0,0,0,2)")?.alpha, 1)
        XCTAssertEqual(RendererColor(css: "rgba(0,0,0,-1)")?.alpha, 0)
    }

    func testNumericParserMatchesExistingAcceptedAndRejectedGrammar() {
        for value in ["#FF0000", "#12345680", "rgb(14,122,254)", "rgba(1,2,3,0)", "RGB(1,2,3)", "red", "#FFF", "rgb(256,0,0)", "rgba(1,2,3,no)", "", "hsl(0,0,0)"] {
            XCTAssertEqual(RendererColor(css: value) != nil, Color(css: value) != nil, value)
        }
        XCTAssertNotNil(RendererColor(hex: "00FF00"))
    }

    // MARK: - Hex colors

    func testHex6Digit() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }

    func testHex6DigitWithoutHash() {
        let color = Color(hex: "00FF00")
        XCTAssertNotNil(color)
    }

    func testHex8DigitWithAlpha() {
        let color = Color(hex: "#FF000080")
        XCTAssertNotNil(color)
    }

    func testHexInvalidLength() {
        XCTAssertNil(Color(hex: "#FFF"))
        XCTAssertNil(Color(hex: "#FFFFF"))
    }

    func testHexInvalidCharacters() {
        XCTAssertNil(Color(hex: "#GGGGGG"))
    }

    // MARK: - CSS rgb()

    func testRGB() {
        let color = Color(css: "rgb(14,122,254)")
        XCTAssertNotNil(color)
    }

    func testRGBWithSpaces() {
        let color = Color(css: "rgb(14, 122, 254)")
        XCTAssertNotNil(color)
    }

    func testRGBA() {
        let color = Color(css: "rgba(14,122,254,0.1)")
        XCTAssertNotNil(color)
    }

    func testRGBAFullOpacity() {
        let color = Color(css: "rgba(255, 255, 255, 1)")
        XCTAssertNotNil(color)
    }

    func testRGBAZeroOpacity() {
        let color = Color(css: "rgba(0, 0, 0, 0)")
        XCTAssertNotNil(color)
    }

    func testRGBOutOfRange() {
        XCTAssertNil(Color(css: "rgb(256, 0, 0)"))
        XCTAssertNil(Color(css: "rgb(-1, 0, 0)"))
    }

    func testRGBAAlphaClamped() {
        // Alpha > 1 should be clamped to 1
        let color = Color(css: "rgba(0, 0, 0, 2.0)")
        XCTAssertNotNil(color)
    }

    func testRGBANonNumericAlphaRejected() {
        XCTAssertNil(Color(css: "rgba(0, 0, 0, abc)"))
    }

    func testRGBMissingParts() {
        XCTAssertNil(Color(css: "rgb(14, 122)"))
    }

    func testRGBExtraParts() {
        XCTAssertNil(Color(css: "rgb(14, 122, 254, 0.5)"))
    }

    func testRGBAMissingAlpha() {
        XCTAssertNil(Color(css: "rgba(14, 122, 254)"))
    }

    // MARK: - CSS unified dispatcher

    func testCSSDispatchesHex() {
        let color = Color(css: "#8bb92d")
        XCTAssertNotNil(color)
    }

    func testCSSDispatchesRGB() {
        let color = Color(css: "rgb(139, 185, 45)")
        XCTAssertNotNil(color)
    }

    func testCSSDispatchesRGBA() {
        let color = Color(css: "rgba(139, 185, 45, 0.5)")
        XCTAssertNotNil(color)
    }

    func testCSSReturnsNilForUnknown() {
        XCTAssertNil(Color(css: "hsl(120, 100%, 50%)"))
        XCTAssertNil(Color(css: "red"))
        XCTAssertNil(Color(css: ""))
    }

    func testCSSCaseInsensitive() {
        XCTAssertNotNil(Color(css: "RGB(14, 122, 254)"))
        XCTAssertNotNil(Color(css: "RGBA(14, 122, 254, 0.5)"))
    }

    func testCSSTrimsWhitespace() {
        XCTAssertNotNil(Color(css: "  #FF0000  "))
        XCTAssertNotNil(Color(css: "  rgb(14, 122, 254)  "))
    }
}
