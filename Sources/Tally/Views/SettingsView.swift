import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StatsStore

    @AppStorage("menuBarMode") private var menuBarMode = "cost"
    @AppStorage("appLanguage") private var appLanguage = "system"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var claudeProjectsPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
    }
    private var codexSessionsPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions").path
    }
    private var ccSwitchPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cc-switch/cc-switch.db").path
    }

    var body: some View {
        let _ = appLanguage
        Form {
            Section(L10n.t("Menu Bar")) {
                Picker(L10n.t("Show"), selection: $menuBarMode) {
                    Text(L10n.t("Cost")).tag("cost")
                    Text(L10n.t("Tokens")).tag("tokens")
                    Text(L10n.t("Icon only")).tag("icon")
                }
            }

            Section(L10n.t("Refresh")) {
                Picker(L10n.t("Refresh every"), selection: $store.refreshInterval) {
                    Text(L10n.t("30 seconds")).tag(30)
                    Text(L10n.t("1 minute")).tag(60)
                    Text(L10n.t("5 minutes")).tag(300)
                }
                .onChange(of: store.refreshInterval) { _, _ in
                    store.startTimer()
                }
            }

            Section(L10n.t("General")) {
                Toggle(L10n.t("Launch at Login"), isOn: $launchAtLogin)
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

            Section(L10n.t("Language")) {
                Picker(L10n.t("Language"), selection: $appLanguage) {
                    Text(L10n.t("System")).tag("system")
                    Text("English").tag("en")
                    Text("简体中文").tag("zh")
                }
            }

            Section(L10n.t("Quota")) {
                Toggle(L10n.t("Show Claude subscription quota"), isOn: $store.fetchClaudeQuota)
                Text(L10n.t("Queries Anthropic's usage endpoint with the credentials Claude Code already stores — Tally's only network call. The first time, approve the Keychain prompt (Always Allow). Codex quota comes from local logs, no prompt."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.t("Data")) {
                dataSourceRow(label: L10n.t("Claude logs"), display: "~/.claude/projects",
                              path: claudeProjectsPath)
                dataSourceRow(label: L10n.t("Codex logs"), display: "~/.codex/sessions",
                              path: codexSessionsPath)
                dataSourceRow(label: "cc-switch", display: "~/.cc-switch/cc-switch.db",
                              path: ccSwitchPath)
            }

            Text("Tally v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 420)
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
