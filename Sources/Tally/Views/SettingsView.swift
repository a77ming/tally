import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StatsStore

    @AppStorage("menuBarMode") private var menuBarMode = "cost"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var claudeProjectsPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
    }
    private var ccSwitchPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cc-switch/cc-switch.db").path
    }

    var body: some View {
        Form {
            Section("Menu Bar") {
                Picker("Show", selection: $menuBarMode) {
                    Text("Cost").tag("cost")
                    Text("Tokens").tag("tokens")
                    Text("Icon only").tag("icon")
                }
            }

            Section("Refresh") {
                Picker("Refresh every", selection: $store.refreshInterval) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                }
                .onChange(of: store.refreshInterval) { _, _ in
                    store.startTimer()
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        guard newValue != (SMAppService.mainApp.status == .enabled) else { return }
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Fails when not running from a real .app bundle.
                            print("Launch at login failed: \(error)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Data") {
                dataSourceRow(label: "Claude logs", display: "~/.claude/projects",
                              path: claudeProjectsPath)
                dataSourceRow(label: "cc-switch", display: "~/.cc-switch/cc-switch.db",
                              path: ccSwitchPath)
            }

            Text("Tally v1.0.0 — local-only, no network access")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
    }

    private func dataSourceRow(label: String, display: String, path: String) -> some View {
        let exists = FileManager.default.fileExists(atPath: path)
        return LabeledContent(label) {
            HStack(spacing: 6) {
                Text(display)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Circle()
                    .fill(exists ? Color.green : Color.gray)
                    .frame(width: 7, height: 7)
            }
        }
    }
}
