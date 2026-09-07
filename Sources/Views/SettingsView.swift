import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("settings.model") private var modelRaw = LLMModel.opus5.rawValue
    @AppStorage(PersistenceController.iCloudSyncDefaultsKey) private var iCloudSync = false

    @State private var apiKey = KeychainStore.apiKey ?? ""
    @State private var showRelaunchNote = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Anthropic API key") {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Stored in the Keychain on this device. Used only to call the Anthropic API directly.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Model") {
                    Picker("Model", selection: $modelRaw) {
                        ForEach(LLMModel.allCases) { m in
                            Text(m.displayName).tag(m.rawValue)
                        }
                    }
                    if let m = LLMModel(rawValue: modelRaw) {
                        Text(m.costHint).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Sync with iCloud", isOn: $iCloudSync)
                } footer: {
                    Text("Takes effect after you relaunch the app. Requires the iCloud capability in your provisioning profile.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        KeychainStore.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
        }
    }
}
