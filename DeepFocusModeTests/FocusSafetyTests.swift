import XCTest
import AppKit
@testable import DeepFocusMode

final class FocusSafetyTests: XCTestCase {
    @MainActor
    func testRealOverlayWindowsRenderCutoutIgnoreInputAndClose() async throws {
        let screen = try XCTUnwrap(NSScreen.screens.first)
        let existingWindows = Set(NSApp.windows.map(\.windowNumber))
        let renderer = DimmingOverlayController()
        defer { renderer.clear() }
        let focus = screen.frame.insetBy(dx: screen.frame.width / 4, dy: screen.frame.height / 4)
        renderer.render(focusedWindow: focus, opacity: 0.45)
        let panels = NSApp.windows.filter { !existingWindows.contains($0.windowNumber) }
        XCTAssertEqual(panels.count, NSScreen.screens.count)
        for panel in panels {
            XCTAssertTrue(panel.isVisible)
            XCTAssertTrue(panel.ignoresMouseEvents)
            XCTAssertFalse(panel.canBecomeKey)
            XCTAssertFalse(panel.canBecomeMain)
        }
        let primaryPanel = try XCTUnwrap(panels.first { $0.frame == screen.frame })
        let view = try XCTUnwrap(primaryPanel.contentView)
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let outside = try XCTUnwrap(bitmap.colorAt(x: 2, y: 2))
        let inside = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
        XCTAssertEqual(outside.alphaComponent, 0.45, accuracy: 0.03)
        XCTAssertEqual(inside.alphaComponent, 0, accuracy: 0.01)
        renderer.clear()
        XCTAssertTrue(panels.allSatisfy { !$0.isVisible })
    }

    @MainActor
    func testRoundedCutoutShadesCornersAndPreservesShapeAtDisplayEdge() async throws {
        let screen = try XCTUnwrap(NSScreen.screens.first)
        let existingWindows = Set(NSApp.windows.map(\.windowNumber))
        let renderer = DimmingOverlayController()
        defer { renderer.clear() }
        let focus = screen.frame.insetBy(dx: screen.frame.width / 4, dy: screen.frame.height / 4)
        renderer.render(focusedWindow: focus, opacity: 0.45)
        let panel = try XCTUnwrap(NSApp.windows.first {
            !existingWindows.contains($0.windowNumber) && $0.frame == screen.frame
        })
        let view = try XCTUnwrap(panel.contentView)
        let local = focus.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)

        func capture() throws -> NSBitmapImageRep {
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            return bitmap
        }
        func alpha(_ bitmap: NSBitmapImageRep, _ x: CGFloat, _ y: CGFloat) throws -> CGFloat {
            let pixelX = Int(x * CGFloat(bitmap.pixelsWide) / view.bounds.width)
            let pixelY = Int((view.bounds.height - y) * CGFloat(bitmap.pixelsHigh) / view.bounds.height)
            return try XCTUnwrap(bitmap.colorAt(x: pixelX, y: pixelY)).alphaComponent
        }
        let bitmap = try capture()
        for x in [local.minX + 1, local.maxX - 1] {
            for y in [local.minY + 1, local.maxY - 1] {
                XCTAssertEqual(try alpha(bitmap, x, y), 0.45, accuracy: 0.03)
            }
        }
        XCTAssertEqual(try alpha(bitmap, local.midX, local.maxY - 1), 0, accuracy: 0.01)
        XCTAssertEqual(try alpha(bitmap, local.minX + 1, local.midY), 0, accuracy: 0.01)
        XCTAssertEqual(try alpha(bitmap, local.minX + 6, local.minY + 6), 0, accuracy: 0.01)

        // A window crossing the left edge must keep its real corners offscreen.
        let crossing = CGRect(x: screen.frame.minX - 100, y: focus.minY,
                              width: 200, height: focus.height)
        renderer.render(focusedWindow: crossing, opacity: 0.45)
        let updated = try capture()
        XCTAssertEqual(try alpha(updated, 1, local.minY + 1), 0, accuracy: 0.01)
        XCTAssertEqual(try alpha(updated, local.midX, local.midY), 0.45, accuracy: 0.03)
        XCTAssertTrue(panel.isVisible)
        XCTAssertTrue(panel.ignoresMouseEvents)
    }

    @MainActor
    func testMissingPermissionNeverStartsTrackingOrRendering() async {
        let provider = FocusStub()
        let renderer = RenderSpy()
        let coordinator = FocusCoordinator(provider: provider, renderer: renderer)
        coordinator.setEnabled(true, permissionGranted: false)
        provider.onChange?(.window(CGRect(x: 100, y: 100, width: 500, height: 400)))
        XCTAssertFalse(coordinator.isEnabled)
        XCTAssertEqual(coordinator.status, .permissionNeeded)
        XCTAssertEqual(provider.starts, 0)
        XCTAssertEqual(renderer.renders, 0)
    }

    @MainActor
    func testRevocationClearsOverlayAndLateEventsCannotRestoreIt() async {
        let provider = FocusStub()
        let renderer = RenderSpy()
        let coordinator = FocusCoordinator(provider: provider, renderer: renderer)
        coordinator.setEnabled(true, permissionGranted: true)
        provider.onChange?(.window(CGRect(x: 100, y: 100, width: 500, height: 400)))
        XCTAssertTrue(renderer.visible)
        coordinator.permissionRevoked()
        provider.onChange?(.window(CGRect(x: 200, y: 200, width: 500, height: 400)))
        XCTAssertFalse(renderer.visible)
        XCTAssertFalse(coordinator.isEnabled)
        XCTAssertEqual(provider.stops, 1)
        XCTAssertEqual(renderer.renders, 1)
    }

    @MainActor
    func testMissingFocusAndUnsupportedSpacesClearOverlayWithoutDisablingToggle() async {
        let provider = FocusStub()
        let renderer = RenderSpy()
        let coordinator = FocusCoordinator(provider: provider, renderer: renderer)
        coordinator.setEnabled(true, permissionGranted: true)
        provider.onChange?(.window(CGRect(x: 0, y: 0, width: 500, height: 400)))
        provider.onChange?(.unavailable)
        XCTAssertFalse(renderer.visible)
        XCTAssertTrue(coordinator.isEnabled)
        provider.onChange?(.unsupported)
        XCTAssertEqual(coordinator.status, .unsupported)
        XCTAssertFalse(renderer.visible)
        provider.onChange?(.window(CGRect(x: 0, y: 0, width: 500, height: 400)))
        XCTAssertTrue(renderer.visible)
    }

    @MainActor
    func testDisablingStopsTrackingAndClearsOverlay() async {
        let provider = FocusStub()
        let renderer = RenderSpy()
        let coordinator = FocusCoordinator(provider: provider, renderer: renderer)
        coordinator.setEnabled(true, permissionGranted: true)
        provider.onChange?(.window(CGRect(x: 0, y: 0, width: 500, height: 400)))
        coordinator.setEnabled(false, permissionGranted: true)
        XCTAssertFalse(renderer.visible)
        XCTAssertEqual(coordinator.status, .off)
        XCTAssertEqual(provider.stops, 1)
    }

    @MainActor
    func testRelaunchLoadsOpacityButNeverRestoresEnabledState() async {
        let suiteName = "DeepFocusModeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.opacity = 0.6
        XCTAssertEqual(PreferencesStore(defaults: defaults).opacity, 0.6)
        let coordinator = FocusCoordinator(provider: FocusStub(), renderer: RenderSpy())
        XCTAssertFalse(coordinator.isEnabled)
    }

    @MainActor
    func testCorruptOpacityAndOutOfRangeValuesAreSafe() async {
        XCTAssertEqual(PreferencesStore.validatedOpacity(.nan), 0.45)
        XCTAssertEqual(PreferencesStore.validatedOpacity(.infinity), 0.45)
        XCTAssertEqual(PreferencesStore.validatedOpacity(-1), 0)
        XCTAssertEqual(PreferencesStore.validatedOpacity(1), 0.85)
    }
}

@MainActor
private final class FocusStub: WindowFocusProviding {
    var onChange: ((FocusSnapshot) -> Void)?
    var starts = 0
    var stops = 0
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func refresh() {}
}

@MainActor
private final class RenderSpy: DimmingRendering {
    var renders = 0
    var visible = false
    func render(focusedWindow: CGRect, opacity: Double) { renders += 1; visible = opacity > 0 }
    func clear() { visible = false }
}
