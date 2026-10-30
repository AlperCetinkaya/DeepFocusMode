import AppKit
import ApplicationServices
import OSLog

enum FocusSnapshot: Equatable {
    case window(CGRect)
    case unavailable
    case unsupported
}

@MainActor
protocol WindowFocusProviding: AnyObject {
    var onChange: ((FocusSnapshot) -> Void)? { get set }
    func start()
    func stop()
    func refresh()
}

@MainActor
final class WindowFocusProvider: WindowFocusProviding {
    var onChange: ((FocusSnapshot) -> Void)?
    private var workspaceTokens: [NSObjectProtocol] = []
    private var appTokens: [NSObjectProtocol] = []
    private var observer: AXObserver?
    private var observedApplication: AXUIElement?
    private var observedWindow: AXUIElement?
    private var observedPID: pid_t?
    private var refreshWork: DispatchWorkItem?
    private var isRunning = false
    private let logger = Logger(subsystem: "com.alpercetinkaya.deepfocusmode", category: "WindowFocus")
    private var lastDiagnostic = ""
    private let appNotifications = [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification,
                                    kAXFocusedUIElementChangedNotification]
    private let windowNotifications = [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification]

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification] {
            workspaceTokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRefresh() }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspaceTokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshWork?.cancel()
                    self?.onChange?(.unavailable)
                }
            })
        }
        workspaceTokens.append(workspace.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification,
                                                     object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRefresh() }
        })
        appTokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRefresh() }
        })
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didMoveNotification,
                     NSWindow.didResizeNotification, NSWindow.willCloseNotification] {
            appTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    // The borderless overlay panels must never trigger a refresh themselves.
                    guard let window = notification.object as? NSWindow,
                          window.styleMask.contains(.titled) else { return }
                    self?.scheduleRefresh()
                }
            })
        }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            appTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRefresh() }
            })
        }
        refresh()
    }

    func stop() {
        isRunning = false
        refreshWork?.cancel()
        refreshWork = nil
        workspaceTokens.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        appTokens.forEach(NotificationCenter.default.removeObserver)
        workspaceTokens.removeAll()
        appTokens.removeAll()
        removeAXObserver()
    }

    private func scheduleRefresh() {
        guard isRunning else { return }
        onChange?(.unavailable)
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
    }

    func refresh() {
        guard isRunning, AXIsProcessTrusted() else {
            unavailable("permission_missing_or_tracking_stopped")
            return
        }
        // Settings is a real focus target too: changing opacity should show its effect
        // immediately, without activating another app or asking AX about our own process.
        if NSApp.isActive, let window = NSApp.keyWindow,
           window.styleMask.contains(.titled), window.isVisible {
            onChange?(.window(window.frame))
            return
        }
        guard
              let app = NSWorkspace.shared.frontmostApplication,
              app.activationPolicy == .regular,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !Self.protectedApps.contains(app.bundleIdentifier ?? "") else {
            unavailable("inactive_or_protected_app")
            return
        }
        attachObserver(to: app.processIdentifier)
        guard observer != nil else {
            onChange?(.unsupported)
            return
        }
        guard let application = observedApplication,
              let window = attribute(application, kAXFocusedWindowAttribute),
              CFGetTypeID(window) == AXUIElementGetTypeID() else {
            unavailable("focused_window_missing")
            return
        }
        let focusedWindow = unsafeBitCast(window, to: AXUIElement.self)
        guard observeWindow(focusedWindow) else {
            onChange?(.unsupported)
            return
        }
        guard let subrole = attribute(focusedWindow, kAXSubroleAttribute) as? String,
              subrole == kAXStandardWindowSubrole,
              (attribute(focusedWindow, kAXModalAttribute) as? Bool) != true,
              !hasSheet(focusedWindow),
              let pointValue = attribute(focusedWindow, kAXPositionAttribute),
              let sizeValue = attribute(focusedWindow, kAXSizeAttribute),
              CFGetTypeID(pointValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            unavailable("window_geometry_or_modal")
            return
        }
        // Finder may keep its last window around while the desktop has keyboard focus.
        if app.bundleIdentifier == "com.apple.finder",
           let focused = attribute(application, kAXFocusedUIElementAttribute),
           CFGetTypeID(focused) == AXUIElementGetTypeID() {
            let element = unsafeBitCast(focused, to: AXUIElement.self)
            guard let ownerWindow = attribute(element, kAXWindowAttribute),
                  CFEqual(ownerWindow, focusedWindow) else {
                unavailable("finder_desktop_or_focus_transition")
                return
            }
        }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(pointValue, to: AXValue.self), .cgPoint, &origin),
              AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size),
              let primary = NSScreen.screens.first,
              let rect = OverlayGeometry.appKitRect(fromAX: CGRect(origin: origin, size: size),
                                                     primaryDisplayHeight: primary.frame.height),
              NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) else {
            unavailable("invalid_or_offscreen_geometry")
            return
        }
        // Full-screen behavior needs separate device QA; avoid shading other Spaces in this spike.
        if NSScreen.screens.contains(where: {
            rect.insetBy(dx: -1, dy: -1).contains($0.frame)
        }) {
            onChange?(.unsupported)
        } else {
            if lastDiagnostic != "ready" {
                logger.notice("Window tracking ready")
                lastDiagnostic = "ready"
            }
            onChange?(.window(rect))
        }
    }

    private func unavailable(_ reason: String) {
        if reason != lastDiagnostic {
            logger.notice("Window tracking paused: \(reason, privacy: .public)")
            lastDiagnostic = reason
        }
        onChange?(.unavailable)
    }

    private static let protectedApps: Set<String> = [
        "com.apple.systempreferences", "com.apple.SecurityAgent", "com.apple.loginwindow",
        "com.apple.notificationcenterui", "com.apple.controlcenter", "com.apple.dock"
    ]

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func hasSheet(_ window: AXUIElement) -> Bool {
        let children = attribute(window, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return children.contains { attribute($0, kAXRoleAttribute) as? String == kAXSheetRole }
    }

    private func attachObserver(to pid: pid_t) {
        guard observedPID != pid || observer == nil else { return }
        removeAXObserver()
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.2)
        observedApplication = application
        observedPID = pid
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<WindowFocusProvider>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }
        let createResult = AXObserverCreate(pid, callback, &created)
        guard createResult == .success, let created else {
            logger.error("AX observer creation failed: \(createResult.rawValue)")
            return
        }
        // Without focus-change notifications, an old cutout could remain over a new window.
        let focusResult = AXObserverAddNotification(created, application, kAXFocusedWindowChangedNotification as CFString,
                                                    Unmanaged.passUnretained(self).toOpaque())
        guard focusResult == .success else {
            logger.error("AX focus notification registration failed: \(focusResult.rawValue)")
            return
        }
        observer = created
        for name in appNotifications.dropFirst() {
            AXObserverAddNotification(created, application, name as CFString,
                                      Unmanaged.passUnretained(self).toOpaque())
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
    }

    private func observeWindow(_ window: AXUIElement) -> Bool {
        guard let observer else { return false }
        if let old = observedWindow, CFEqual(old, window) { return true }
        if let old = observedWindow {
            for name in windowNotifications { AXObserverRemoveNotification(observer, old, name as CFString) }
        }
        observedWindow = window
        var canTrackGeometry = true
        for name in windowNotifications {
            let result = AXObserverAddNotification(observer, window, name as CFString,
                                                   Unmanaged.passUnretained(self).toOpaque())
            if name != kAXUIElementDestroyedNotification, result != .success {
                canTrackGeometry = false
                logger.error("AX geometry notification registration failed: \(result.rawValue)")
            }
        }
        if !canTrackGeometry {
            for name in windowNotifications { AXObserverRemoveNotification(observer, window, name as CFString) }
            observedWindow = nil
        }
        return canTrackGeometry
    }

    private func removeAXObserver() {
        if let observer {
            if let application = observedApplication {
                for name in appNotifications { AXObserverRemoveNotification(observer, application, name as CFString) }
            }
            if let window = observedWindow {
                for name in windowNotifications { AXObserverRemoveNotification(observer, window, name as CFString) }
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedApplication = nil
        observedWindow = nil
        observedPID = nil
    }
}
