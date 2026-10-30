import SwiftUI

struct FocusSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: PreferencesStore
    @State private var showingPrivacy = false

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
            Section("settings.privacyTitle") {
                Label("privacy.noPermission", systemImage: "checkmark.shield")
                Text("privacy.metadata").font(.caption).foregroundStyle(.secondary)
                Button("privacy.action") { showingPrivacy = true }
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
                Link("support.action", destination: URL(string: "https://github.com/AlperCetinkaya/DeepFocusMode/issues")!)
                Link("support.email", destination: URL(string: "mailto:alper.cetinkaya.dev@gmail.com")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 620)
        .sheet(isPresented: $showingPrivacy) { PrivacyPolicyView() }
    }
}

private struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("privacy.action").font(.title2.bold())
            ScrollView {
                Text("privacy.body").frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            HStack {
                Link("support.action", destination: URL(string: "https://github.com/AlperCetinkaya/DeepFocusMode/issues")!)
                Spacer()
                Button("action.done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540, height: 480)
    }
}
