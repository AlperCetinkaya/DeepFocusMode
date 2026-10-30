import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    let preferences = PreferencesStore()
    private let coordinator = FocusCoordinator(provider: WindowFocusProvider(), renderer: DimmingOverlayController())
    private var opacitySubscription: AnyCancellable?

    var isEnabled: Bool { coordinator.isEnabled }
    var status: FocusStatus { coordinator.status }

    init() {
        coordinator.onChange = { [weak self] in self?.objectWillChange.send() }
        opacitySubscription = preferences.$opacity.sink { [weak self] value in
            self?.coordinator.opacity = value
        }
    }

    func setEnabled(_ enabled: Bool) { coordinator.setEnabled(enabled) }
    func shutdown() { coordinator.setEnabled(false) }
}
