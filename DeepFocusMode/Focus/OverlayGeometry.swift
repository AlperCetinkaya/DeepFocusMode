import CoreGraphics

/// Window Server uses a top-left origin; AppKit uses a bottom-left origin.
enum OverlayGeometry {
    // Public window geometry contains no corner radius. Approximate standard macOS
    // windows in points, so the curve scales correctly on Retina displays.
    static let windowCornerRadius: CGFloat = 12

    static func appKitRect(fromWindowServer rect: CGRect, primaryDisplayHeight: CGFloat) -> CGRect? {
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite,
              rect.width > 1, rect.height > 1 else { return nil }
        return CGRect(x: rect.minX, y: primaryDisplayHeight - rect.maxY,
                      width: rect.width, height: rect.height)
    }

    static func localCutout(window: CGRect, screen: CGRect) -> CGRect? {
        let intersection = window.intersection(screen)
        guard !intersection.isNull, !intersection.isEmpty else { return nil }
        // Preserve the complete window shape. The view clips it to the display;
        // rounding an intersection would introduce corners at display seams.
        return window.offsetBy(dx: -screen.minX, dy: -screen.minY)
    }
}
