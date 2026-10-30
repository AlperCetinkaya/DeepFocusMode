import AppKit
import CoreGraphics

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

/// Retain geometry and numeric identifiers only, never window titles or images.
struct WindowMetadata {
    let id: CGWindowID
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
    let alpha: Double

    init(id: CGWindowID, ownerPID: pid_t, layer: Int = 0, bounds: CGRect, alpha: Double = 1) {
        self.id = id
        self.ownerPID = ownerPID
        self.layer = layer
        self.bounds = bounds
        self.alpha = alpha
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary[kCGWindowNumber as String] as? NSNumber,
              let pid = dictionary[kCGWindowOwnerPID as String] as? NSNumber,
              let layer = dictionary[kCGWindowLayer as String] as? NSNumber,
              let bounds = dictionary[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
              OverlayGeometry.appKitRect(fromWindowServer: rect, primaryDisplayHeight: 0) != nil
        else { return nil }
        self.init(id: id.uint32Value, ownerPID: pid.int32Value, layer: layer.intValue,
                  bounds: rect, alpha: (dictionary[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1)
    }

    static func onScreen() -> [WindowMetadata] {
        // Apple documents this array as front-to-back. No capture API, title key,
        // permission prompt, private API or Accessibility call is used here.
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                              kCGNullWindowID) as? [[String: Any]] ?? []
        return rows.compactMap(WindowMetadata.init(dictionary:))
    }

    static func windowID(from number: Int) -> CGWindowID? {
        guard number > 0 else { return nil }
        return CGWindowID(exactly: number)
    }
}

enum WindowSelection {
    static func snapshot(windows: [WindowMetadata], frontmostPID: pid_t,
                         ignoredWindowIDs: Set<CGWindowID>, protectedPIDs: Set<pid_t>,
                         screens: [CGRect], primaryDisplayHeight: CGFloat) -> FocusSnapshot {
        for window in windows where !ignoredWindowIDs.contains(window.id) && window.alpha > 0 {
            if protectedPIDs.contains(window.ownerPID) { return .unavailable }
            guard window.layer == 0 else { continue }
            // A transition, another app's dialog or an uncertain front window
            // must never leave an opening over a background window.
            guard window.ownerPID == frontmostPID,
                  window.bounds.width >= 100, window.bounds.height >= 80,
                  let rect = OverlayGeometry.appKitRect(fromWindowServer: window.bounds,
                                                        primaryDisplayHeight: primaryDisplayHeight),
                  screens.contains(where: { $0.intersects(rect) }) else { return .unavailable }
            if screens.contains(where: { rect.insetBy(dx: -1, dy: -1).contains($0) }) {
                return .unsupported
            }
            return .window(rect)
        }
        return .unavailable
    }
}

@MainActor
final class WindowFocusProvider: WindowFocusProviding {
    var onChange: ((FocusSnapshot) -> Void)?
    private var workspaceTokens: [NSObjectProtocol] = []
    private var appTokens: [NSObjectProtocol] = []
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var refreshWork: DispatchWorkItem?
    private var reconciliationTimer: Timer?
    private var isRunning = false
    private var isSuspended = false
    private var isDragging = false
    private var finderDesktopSelected = false
    private var lastPointerClick: CGPoint?
    private var lastSnapshot: FocusSnapshot?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isSuspended = false
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceTokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isSuspended = false
                    self?.finderDesktopSelected = false
                    self?.scheduleRefresh()
                }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspaceTokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isSuspended = true
                    self?.refreshWork?.cancel()
                    self?.emit(.unavailable)
                }
            })
        }
        for name in [NSApplication.didChangeScreenParametersNotification,
                     NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
                     NSWindow.didBecomeKeyNotification, NSWindow.didMoveNotification,
                     NSWindow.didResizeNotification, NSWindow.willCloseNotification] {
            appTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let window = note.object as? NSWindow
                MainActor.assumeIsolated {
                    if let window, !window.styleMask.contains(.titled) { return }
                    self?.scheduleRefresh()
                }
            })
        }
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown,
                                                 .leftMouseUp, .rightMouseUp, .otherMouseUp, .leftMouseDragged]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouse(event) }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouse(event) }
            return event // Never consume or modify input; never observe keyboard content.
        }
        // No public cross-app geometry notifications are available without AX.
        // Events handle normal interaction; this low-rate, enabled-only fallback
        // reconciles keyboard-driven window changes. No 60Hz geometry polling.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 0.25
        reconciliationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    func stop() {
        isRunning = false
        refreshWork?.cancel()
        refreshWork = nil
        reconciliationTimer?.invalidate()
        reconciliationTimer = nil
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        workspaceTokens.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        appTokens.forEach(NotificationCenter.default.removeObserver)
        workspaceTokens.removeAll()
        appTokens.removeAll()
        isDragging = false
        finderDesktopSelected = false
        lastPointerClick = nil
        lastSnapshot = nil
    }

    private func handleMouse(_ event: NSEvent) {
        guard isRunning else { return }
        if event.type == .leftMouseDragged {
            isDragging = true
            refreshWork?.cancel()
            emit(.unavailable)
            return
        }
        isDragging = false
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(event.type) {
            lastPointerClick = NSEvent.mouseLocation
        }
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        guard isRunning else { return }
        emit(.unavailable)
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    func refresh() {
        guard isRunning else { return }
        guard !isSuspended, !isDragging, let primary = NSScreen.screens.first else {
            emit(.unavailable)
            return
        }
        if NSApp.isActive, let window = NSApp.keyWindow, window.styleMask.contains(.titled), window.isVisible {
            lastPointerClick = nil
            emit(window.attachedSheet == nil && NSApp.modalWindow == nil ? .window(window.frame) : .unavailable)
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication, app.activationPolicy == .regular,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !Self.protectedApps.contains(app.bundleIdentifier ?? "") else {
            lastPointerClick = nil
            emit(.unavailable)
            return
        }
        let windows = WindowMetadata.onScreen()
        if app.bundleIdentifier == "com.apple.finder" {
            if let point = lastPointerClick {
                finderDesktopSelected = !windows.contains {
                    $0.ownerPID == app.processIdentifier && $0.layer == 0 &&
                    OverlayGeometry.appKitRect(fromWindowServer: $0.bounds, primaryDisplayHeight: primary.frame.height)?.contains(point) == true
                }
            }
        } else { finderDesktopSelected = false }
        lastPointerClick = nil
        guard !finderDesktopSelected else { emit(.unavailable); return }
        let ignored = Set(NSApp.windows.filter { !$0.styleMask.contains(.titled) }
            .compactMap { WindowMetadata.windowID(from: $0.windowNumber) })
        let protected = Set(windows.compactMap { window -> pid_t? in
            guard window.bounds.width > 100, window.bounds.height > 80,
                  let bundleID = NSRunningApplication(processIdentifier: window.ownerPID)?.bundleIdentifier,
                  bundleID != "com.apple.dock",
                  Self.protectedApps.contains(bundleID) else { return nil }
            return window.ownerPID
        })
        emit(WindowSelection.snapshot(windows: windows, frontmostPID: app.processIdentifier,
                                       ignoredWindowIDs: ignored, protectedPIDs: protected,
                                       screens: NSScreen.screens.map(\.frame), primaryDisplayHeight: primary.frame.height))
    }

    private func emit(_ snapshot: FocusSnapshot) {
        guard isRunning, snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        onChange?(snapshot)
    }

    private static let protectedApps: Set<String> = [
        "com.apple.systempreferences", "com.apple.SecurityAgent", "com.apple.loginwindow",
        "com.apple.notificationcenterui", "com.apple.controlcenter", "com.apple.dock",
        "com.apple.LocalAuthentication.UIAgent", "com.apple.CoreServicesUIAgent"
    ]
}
