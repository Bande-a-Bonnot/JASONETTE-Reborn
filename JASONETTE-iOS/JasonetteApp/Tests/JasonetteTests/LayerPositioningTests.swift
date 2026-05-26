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

    func testUnpositionedLayerIsCenteredAndDoesNotStretch() {
        let positioning = LayerPositioning(style: JasonStyle())

        XCTAssertFalse(positioning.stretchesHorizontally)
        XCTAssertFalse(positioning.stretchesVertically)
        XCTAssertTrue(positioning.isUnpositioned)
    }
}
