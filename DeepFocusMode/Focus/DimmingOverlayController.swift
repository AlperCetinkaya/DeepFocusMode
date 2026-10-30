import AppKit

@MainActor
protocol DimmingRendering: AnyObject {
    func render(focusedWindow: CGRect, opacity: Double)
    func clear()
}

@MainActor
final class DimmingOverlayController: DimmingRendering {
    private var panels: [NSPanel] = []

    func render(focusedWindow: CGRect, opacity: Double) {
        guard opacity > 0 else { clear(); return }
        let screens = NSScreen.screens
        if panels.count == screens.count,
           zip(panels, screens).allSatisfy({ $0.0.frame == $0.1.frame }) {
            for (panel, screen) in zip(panels, screens) {
                guard let view = panel.contentView as? ShadeView else { clear(); return }
                view.cutout = OverlayGeometry.localCutout(window: focusedWindow, screen: screen.frame)
                view.opacity = PreferencesStore.validatedOpacity(opacity)
                view.needsDisplay = true
            }
            return
        }
        clear()
        for screen in NSScreen.screens {
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.moveToActiveSpace, .ignoresCycle]
            panel.animationBehavior = .none
            panel.isExcludedFromWindowsMenu = true
            let view = ShadeView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.cutout = OverlayGeometry.localCutout(window: focusedWindow, screen: screen.frame)
            view.opacity = PreferencesStore.validatedOpacity(opacity)
            panel.contentView = view
            panel.setFrame(screen.frame, display: true)
            panels.append(panel)
            panel.orderFrontRegardless()
        }
    }

    func clear() {
        panels.forEach { $0.orderOut(nil); $0.close() }
        panels.removeAll()
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class ShadeView: NSView {
    var cutout: CGRect?
    var opacity = 0.45
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        let path = NSBezierPath(rect: bounds)
        if let cutout {
            path.append(NSBezierPath(roundedRect: cutout,
                                     xRadius: OverlayGeometry.windowCornerRadius,
                                     yRadius: OverlayGeometry.windowCornerRadius))
        }
        path.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(opacity).setFill()
        path.fill()
    }
}
