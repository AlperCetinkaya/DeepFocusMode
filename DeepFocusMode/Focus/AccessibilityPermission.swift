import AppKit
@preconcurrency import ApplicationServices

enum PermissionState: Equatable {
    case unknown, requesting, granted, denied, revoked
}

@MainActor
final class AccessibilityPermission {
    private(set) var state: PermissionState = .unknown

    @discardableResult
    func refresh() -> PermissionState {
        if AXIsProcessTrusted() {
            state = .granted
        } else if state == .granted || state == .revoked {
            state = .revoked
        } else if state != .unknown {
            state = .denied
        }
        return state
    }

    /// Call only after the user chooses Allow, following the in-app explanation.
    func request() {
        state = .requesting
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        refresh()
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
