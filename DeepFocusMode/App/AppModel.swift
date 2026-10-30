import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    let preferences = PreferencesStore()
    private let permission = AccessibilityPermission()
    private let coordinator = FocusCoordinator(provider: WindowFocusProvider(), renderer: DimmingOverlayController())
    @Published private(set) var permissionState: PermissionState = .unknown
    private var opacitySubscription: AnyCancellable?
    private var permissionWatchdog: Timer?

    var isEnabled: Bool { coordinator.isEnabled }
    var status: FocusStatus { coordinator.status }

    init() {
        coordinator.onChange = { [weak self] in self?.objectWillChange.send() }
        opacitySubscription = preferences.$opacity.sink { [weak self] value in
            self?.coordinator.opacity = value
        }
        refreshPermission()
    }

    func setEnabled(_ enabled: Bool) {
        refreshPermission()
        coordinator.setEnabled(enabled, permissionGranted: permissionState == .granted)
        permissionWatchdog?.invalidate()
        permissionWatchdog = nil
        if coordinator.isEnabled {
            // Low-rate trust check only; focus geometry is driven by AX/workspace events.
            permissionWatchdog = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshPermission() }
            }
        }
    }

    func refreshPermission() {
        permissionState = permission.refresh()
        if permissionState != .granted, coordinator.isEnabled {
            coordinator.permissionRevoked()
            permissionWatchdog?.invalidate()
            permissionWatchdog = nil
        }
    }

    func requestPermission() {
        permission.request()
        refreshPermission()
    }

    func openPermissionSettings() { permission.openSettings() }

    func shutdown() {
        permissionWatchdog?.invalidate()
        permissionWatchdog = nil
        coordinator.setEnabled(false, permissionGranted: false)
    }
}
