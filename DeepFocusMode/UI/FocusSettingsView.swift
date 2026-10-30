import SwiftUI

struct FocusSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        Form {
            Section("focus.quick") {
                Toggle("focus.quick", isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) }))
                    .toggleStyle(.switch)
                Text(LocalizedStringKey(model.status.rawValue)).font(.caption).foregroundStyle(.secondary)
            }
            Section("settings.appearance") {
                OpacityControl(preferences: preferences)
                Text("settings.restart").font(.caption).foregroundStyle(.secondary)
            }
            Section("settings.permissions") {
                if model.permissionState == .granted {
                    Label("permission.granted", systemImage: "checkmark.shield")
                    Button("permission.open") { model.openPermissionSettings() }
                } else {
                    PermissionExplanation(model: model)
                }
            }
            Section("settings.about") {
                HStack(spacing: 10) {
                    Image("BrandIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                    Text("Deep Focus Mode").font(.headline)
                }
                Text("settings.privacy").foregroundStyle(.secondary)
                Text("settings.language").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 620)
    }
}
