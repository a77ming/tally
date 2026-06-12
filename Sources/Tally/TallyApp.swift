import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct TallyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = StatsStore()
    @AppStorage("menuBarMode") private var menuBarMode = "cost"

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            MenuBarLabel(store: store, mode: menuBarMode)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var store: StatsStore
    let mode: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 12))
            if mode != "icon" {
                Text(text)
                    .font(.system(size: 12))
                    .monospacedDigit()
            }
        }
    }

    private var text: String {
        let totals = store.totals(for: .today)
        return mode == "tokens" ? Formatters.tokens(totals.totalTokens)
                                : Formatters.cost(totals.cost)
    }
}
