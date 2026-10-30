import XCTest
import CoreGraphics
@testable import DeepFocusMode

final class OverlayGeometryTests: XCTestCase {
    func testWindowServerTopLeftConvertsToAppKitBottomLeft() {
        XCTAssertEqual(OverlayGeometry.appKitRect(fromWindowServer: CGRect(x: 100, y: 50, width: 600, height: 400),
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

    func testDisplayAbovePrimaryPreservesNegativeWindowServerCoordinates() {
        XCTAssertEqual(OverlayGeometry.appKitRect(fromWindowServer: CGRect(x: 0, y: -700, width: 800, height: 600),
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
            XCTAssertNil(OverlayGeometry.appKitRect(fromWindowServer: rect, primaryDisplayHeight: 900))
        }
    }
}

final class WindowSelectionTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let frame = CGRect(x: 100, y: 50, width: 600, height: 400)

    func testClosedAndUnrepresentableWindowNumbersAreIgnored() {
        XCTAssertNil(WindowMetadata.windowID(from: -1))
        XCTAssertNil(WindowMetadata.windowID(from: 0))
        XCTAssertNil(WindowMetadata.windowID(from: Int.max))
        XCTAssertEqual(WindowMetadata.windowID(from: 42), 42)
    }

    private func select(_ windows: [WindowMetadata], ignored: Set<CGWindowID> = [],
                        protected: Set<pid_t> = []) -> FocusSnapshot {
        WindowSelection.snapshot(windows: windows, frontmostPID: 42,
                                 ignoredWindowIDs: ignored, protectedPIDs: protected,
                                 screens: [screen], primaryDisplayHeight: screen.height)
    }

    func testSelectsFrontWindowWithoutTitlesOrPermissionState() throws {
        let rows: [String: Any] = [kCGWindowNumber as String: 1,
                                  kCGWindowOwnerPID as String: 42,
                                  kCGWindowLayer as String: 0,
                                  kCGWindowBounds as String: frame.dictionaryRepresentation]
        let window = try XCTUnwrap(WindowMetadata(dictionary: rows))
        XCTAssertEqual(select([window]), .window(CGRect(x: 100, y: 450, width: 600, height: 400)))
    }

    func testDoesNotFallBackToOldWindowDuringAppTransition() {
        XCTAssertEqual(select([WindowMetadata(id: 1, ownerPID: 99, bounds: frame),
                               WindowMetadata(id: 2, ownerPID: 42, bounds: frame)]), .unavailable)
    }

    func testOwnOverlayIsIgnoredAndMenuLayerIsNotTreatedAsFocus() {
        XCTAssertEqual(select([WindowMetadata(id: 10, ownerPID: 5, layer: 3, bounds: screen),
                               WindowMetadata(id: 11, ownerPID: 6, layer: 25, bounds: frame),
                               WindowMetadata(id: 12, ownerPID: 42, bounds: frame)], ignored: [10]),
                       .window(CGRect(x: 100, y: 450, width: 600, height: 400)))
    }

    func testProtectedPromptAheadOfFocusRemovesDimming() {
        XCTAssertEqual(select([WindowMetadata(id: 1, ownerPID: 99, layer: 8, bounds: frame),
                               WindowMetadata(id: 2, ownerPID: 42, bounds: frame)], protected: [99]), .unavailable)
    }

    func testFullscreenAndMissingWindowsAreSafe() {
        XCTAssertEqual(select([WindowMetadata(id: 1, ownerPID: 42, bounds: screen)]), .unsupported)
        XCTAssertEqual(select([]), .unavailable)
        XCTAssertEqual(select([WindowMetadata(id: 1, ownerPID: 42, bounds: frame, alpha: 0)]), .unavailable)
    }

    func testInvalidOrOffscreenGeometryNeverProducesAnOpening() {
        XCTAssertNil(WindowMetadata(dictionary: [:]))
        XCTAssertEqual(select([WindowMetadata(id: 1, ownerPID: 42,
                                              bounds: CGRect(x: 9999, y: 0, width: 500, height: 400))]), .unavailable)
        XCTAssertEqual(select([WindowMetadata(id: 1, ownerPID: 42,
                                              bounds: CGRect(x: CGFloat.nan, y: 0, width: 500, height: 400))]), .unavailable)
    }
}
