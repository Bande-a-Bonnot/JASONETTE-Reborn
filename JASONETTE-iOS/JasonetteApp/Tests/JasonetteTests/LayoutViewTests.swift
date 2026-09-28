import XCTest
@testable import Jasonette

final class LayoutViewTests: XCTestCase {
    func testEqualsizeWidthsSubtractRowPaddingAndSpacingOnce() {
        let widths = HorizontalLayoutSizing.childWidths(
            containerWidth: 300,
            paddingLeft: 15,
            paddingRight: 15,
            spacing: 10,
            widthModes: [.flexible, .flexible],
            idealWidths: [420, 360],
            distribution: "equalsize"
        )

        XCTAssertEqual(widths.count, 2)
        XCTAssertEqual(widths[0], 130, accuracy: 0.001)
        XCTAssertEqual(widths[1], 130, accuracy: 0.001)
        XCTAssertTrue(widths.allSatisfy(\.isFinite))
    }

    func testNestedAvatarAndFlexibleTextStayWithinFiniteRowWidth() {
        let widths = HorizontalLayoutSizing.childWidths(
            containerWidth: 300,
            paddingLeft: 0,
            paddingRight: 0,
            spacing: 10,
            widthModes: [.fixed(48), .flexible],
            idealWidths: [48, 520],
            distribution: "fill"
        )

        XCTAssertEqual(widths[0], 48, accuracy: 0.001)
        XCTAssertEqual(widths[1], 242, accuracy: 0.001)
        XCTAssertEqual(widths[0] + widths[1] + 10, 300, accuracy: 0.001)
    }

    func testNumericWidthSpacingAndPaddingReserveFixedChildFirst() {
        let widths = HorizontalLayoutSizing.childWidths(
            containerWidth: 300,
            paddingLeft: 15,
            paddingRight: 15,
            spacing: 10,
            widthModes: [.fixed(48), .flexible],
            idealWidths: [48, 500],
            distribution: "fill"
        )

        XCTAssertEqual(widths[0], 48, accuracy: 0.001)
        XCTAssertEqual(widths[1], 212, accuracy: 0.001)
        XCTAssertEqual(widths[0] + widths[1] + 10 + 30, 300, accuracy: 0.001)
    }

    func testUnresolvedPercentageWidthKeepsIntrinsicRenderingMode() {
        let percentage = HorizontalChildWidth(style: JasonStyle(width: AnyCodable("100%")))
        XCTAssertEqual(percentage, .intrinsic)

        let widths = HorizontalLayoutSizing.childWidths(
            containerWidth: 300,
            paddingLeft: 15,
            paddingRight: 15,
            spacing: 10,
            widthModes: [percentage, .flexible],
            idealWidths: [120, 80],
            distribution: "fill"
        )
        XCTAssertEqual(widths, [120, 140])
    }
}
