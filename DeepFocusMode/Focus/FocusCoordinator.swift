import Foundation

enum FocusStatus: String {
    case off = "status.off"
    case permissionNeeded = "status.permission"
    case waiting = "status.waiting"
    case active = "status.active"
    case unsupported = "status.unsupported"
}

@MainActor
final class FocusCoordinator {
    private let provider: WindowFocusProviding
    private let renderer: DimmingRendering
    private var latest: FocusSnapshot = .unavailable
    private(set) var isEnabled = false
    private(set) var status: FocusStatus = .off
    var onChange: (() -> Void)?
    var opacity: Double = PreferencesStore.defaultOpacity {
        didSet { if isEnabled { consume(latest) } }
    }

    init(provider: WindowFocusProviding, renderer: DimmingRendering) {
        self.provider = provider
        self.renderer = renderer
        provider.onChange = { [weak self] snapshot in self?.consume(snapshot) }
    }

    func setEnabled(_ enabled: Bool, permissionGranted: Bool) {
        renderer.clear()
        latest = .unavailable
        isEnabled = enabled && permissionGranted
        if isEnabled {
            status = .waiting
            provider.start()
        } else {
            provider.stop()
            status = enabled ? .permissionNeeded : .off
        }
        onChange?()
    }

    func permissionRevoked() {
        setEnabled(false, permissionGranted: false)
        status = .permissionNeeded
        onChange?()
    }

    private func consume(_ snapshot: FocusSnapshot) {
        guard isEnabled else { return }
        latest = snapshot
        switch snapshot {
        case .window(let rect):
            renderer.render(focusedWindow: rect, opacity: opacity)
            status = opacity > 0 ? .active : .waiting
        case .unavailable:
            renderer.clear()
            status = .waiting
        case .unsupported:
            renderer.clear()
            status = .unsupported
        }
        onChange?()
    }
}
