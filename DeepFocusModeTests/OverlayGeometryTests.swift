import XCTest
@testable import DeepFocusMode

final class OverlayGeometryTests: XCTestCase {
    func testAXTopLeftConvertsToAppKitBottomLeft() {
        XCTAssertEqual(OverlayGeometry.appKitRect(fromAX: CGRect(x: 100, y: 50, width: 600, height: 400),
                                                 primaryDisplayHeight: 900),
                       CGRect(x: 100, y: 450, width: 600, height: 400))
    }

    func testWindowSpanningLeftDisplayHasCorrectLocalCutout() {
        let window = CGRect(x: -200, y: 100, width: 700, height: 400)
        let leftScreen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        XCTAssertEqual(OverlayGeometry.localCutout(window: window, screen: leftScreen),
                       CGRect(x: 1240, y: 100, width: 700, height: 400))
        XCTAssertEqual(OverlayGeometry.localCutout(window: window, screen: CGRect(x: 0, y: 0, width: 1440, height: 900)),
                       CGRect(x: -200, y: 100, width: 700, height: 400))
    }

    func testDisplayAbovePrimaryPreservesNegativeAXCoordinates() {
        XCTAssertEqual(OverlayGeometry.appKitRect(fromAX: CGRect(x: 0, y: -700, width: 800, height: 600),
                                                 primaryDisplayHeight: 900),
                       CGRect(x: 0, y: 1000, width: 800, height: 600))
    }

    func testOffscreenWindowHasNoCutout() {
        XCTAssertNil(OverlayGeometry.localCutout(window: CGRect(x: 1500, y: 0, width: 400, height: 400),
                                                 screen: CGRect(x: 0, y: 0, width: 1440, height: 900)))
    }

    func testCorruptGeometryIsRejected() {
        for rect in [CGRect.zero, CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100),
                     CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 100)] {
            XCTAssertNil(OverlayGeometry.appKitRect(fromAX: rect, primaryDisplayHeight: 900))
        }
    }
}
