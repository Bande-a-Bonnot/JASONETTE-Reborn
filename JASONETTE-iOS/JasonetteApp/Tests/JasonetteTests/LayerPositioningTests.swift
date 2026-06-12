import XCTest
@testable import Jasonette

final class LayerPositioningTests: XCTestCase {
    func testLeftAndRightInsetsStretchHorizontallyBetweenEdges() {
        let style = JasonStyle(left: AnyCodable(12), right: AnyCodable(24))
        let positioning = LayerPositioning(style: style)

        XCTAssertTrue(positioning.stretchesHorizontally)
        XCTAssertFalse(positioning.stretchesVertically)
        XCTAssertEqual(positioning.insets.leading, 12)
        XCTAssertEqual(positioning.insets.trailing, 24)
    }

    func testTopAndBottomInsetsStretchVerticallyBetweenEdges() {
        let style = JasonStyle(top: AnyCodable(8), bottom: AnyCodable(16))
        let positioning = LayerPositioning(style: style)

        XCTAssertFalse(positioning.stretchesHorizontally)
        XCTAssertTrue(positioning.stretchesVertically)
        XCTAssertEqual(positioning.insets.top, 8)
        XCTAssertEqual(positioning.insets.bottom, 16)
    }

    func testSingleEdgePositioningDoesNotStretch() {
        let style = JasonStyle(top: AnyCodable(8), right: AnyCodable(16))
        let positioning = LayerPositioning(style: style)

        XCTAssertFalse(positioning.stretchesHorizontally)
        XCTAssertFalse(positioning.stretchesVertically)
        XCTAssertEqual(positioning.insets.top, 8)
        XCTAssertEqual(positioning.insets.trailing, 16)
    }

    func testLayerLengthResolverSupportsLegacyPercentMinusOffset() {
        XCTAssertEqual(LayerLengthResolver.resolve("50%-43", relativeTo: 390), 152)
        XCTAssertEqual(LayerLengthResolver.resolve("50% - 43", relativeTo: 390), 152)
        XCTAssertEqual(LayerLengthResolver.resolve("calc(50% - 43)", relativeTo: 390), 152)
    }

    func testContainerRelativePositioningUsesMatchingAxis() throws {
        let style = JasonStyle(
            top: AnyCodable("10%"),
            left: AnyCodable("50%-43"),
            bottom: AnyCodable("70"),
            right: AnyCodable("5%")
        )
        let positioning = LayerPositioning(style: style, containerSize: CGSize(width: 390, height: 844))

        XCTAssertEqual(try XCTUnwrap(positioning.top), 84.4, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(positioning.left), 152, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(positioning.bottom), 70, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(positioning.right), 19.5, accuracy: 0.001)
    }

    func testPercentagePositioningWithoutContainerRemainsUnresolved() {
        let style = JasonStyle(left: AnyCodable("50%-43"))
        let positioning = LayerPositioning(style: style)

        XCTAssertNil(positioning.left)
    }

    func testUnpositionedLayerIsCenteredAndDoesNotStretch() {
        let positioning = LayerPositioning(style: JasonStyle())

        XCTAssertFalse(positioning.stretchesHorizontally)
        XCTAssertFalse(positioning.stretchesVertically)
        XCTAssertTrue(positioning.isUnpositioned)
    }
}
