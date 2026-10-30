import SwiftUI

@main
struct DeepFocusModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            FocusMenuView(model: delegate.model, preferences: delegate.model.preferences)
        } label: {
            FocusMenuLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            FocusSettingsView(model: delegate.model, preferences: delegate.model.preferences)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var welcomeWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !UserDefaults.standard.bool(forKey: "onboarding.presented") else { return }
        showSettings()
        UserDefaults.standard.set(true, forKey: "onboarding.presented")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func showSettings() {
        if welcomeWindow == nil {
            let view = FocusSettingsView(model: model, preferences: model.preferences)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = String(localized: "settings.windowTitle")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            welcomeWindow = window
        }
        welcomeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
}

private struct FocusMenuLabel: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Image(nsImage: menuImage)
            .renderingMode(.template)
            .frame(width: 16, height: 16)
            .accessibilityLabel("Deep Focus Mode")
            .accessibilityValue(Text(LocalizedStringKey(model.status.rawValue)))
    }

    private var menuImage: NSImage {
        let name = model.isEnabled ? "MenuBarActive" : "MenuBarInactive"
        let image = (NSImage(named: name)?.copy() as? NSImage) ?? NSImage(size: NSSize(width: 16, height: 16))
        // MenuBarExtra can use the underlying NSImage size rather than SwiftUI's frame.
        // Resize a copy so the shared asset remains unchanged for other consumers.
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }
}
