import Combine
import Foundation

@MainActor
final class PreferencesStore: ObservableObject {
    static let defaultOpacity = 0.45
    private let defaults: UserDefaults

    @Published var opacity: Double {
        didSet {
            let safe = Self.validatedOpacity(opacity)
            if safe != opacity { opacity = safe }
            defaults.set(safe, forKey: "dimming.opacity")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        opacity = Self.validatedOpacity(
            defaults.object(forKey: "dimming.opacity") as? Double ?? Self.defaultOpacity
        )
    }

    static func validatedOpacity(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 0.85) : defaultOpacity
    }
}
