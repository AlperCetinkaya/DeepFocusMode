import SwiftUI

struct FocusMenuView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Deep Focus Mode").font(.headline)
                    Text("app.tagline").font(.caption).foregroundStyle(.secondary)
                }
            }

            Toggle("focus.quick", isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) }))
                .toggleStyle(.switch)
            Text(LocalizedStringKey(model.status.rawValue))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.updatesFrequently)

            OpacityControl(preferences: preferences)

            if model.permissionState != .granted {
                PermissionExplanation(model: model)
            }

            Divider()
            HStack {
                SettingsLink { Label("action.settings", systemImage: "gearshape") }
                Spacer()
                Button("action.quit") { model.shutdown(); NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(20)
        .frame(width: 350)
    }
}

struct OpacityControl: View {
    @ObservedObject var preferences: PreferencesStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("dimming.intensity")
                Spacer()
                Text(preferences.opacity, format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $preferences.opacity, in: 0...0.85) { Text("dimming.intensity") }
                .labelsHidden()
        }
    }
}

struct PermissionExplanation: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("permission.title", systemImage: "hand.raised")
                .font(.subheadline.weight(.semibold))
            Text("permission.explanation").font(.caption).foregroundStyle(.secondary)
            if model.permissionState == .revoked {
                Text("permission.revoked").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("permission.allow") { model.requestPermission() }
                Button("permission.open") { model.openPermissionSettings() }
            }
            Button("permission.check") { model.refreshPermission() }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
