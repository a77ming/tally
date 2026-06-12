import Foundation
import Security

/// Fetches the official Claude subscription quota (5-hour and weekly windows)
/// from Anthropic's OAuth usage endpoint, authenticating with the credentials
/// Claude Code already stores in the Keychain. This is Tally's only network
/// call and can be disabled in Settings.
enum ClaudeQuotaFetcher {
    static func fetch() async -> CodexQuota? {
        guard let token = accessToken() else { return nil }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        struct Usage: Decodable {
            struct Window: Decodable { let utilization: Double? }
            let five_hour: Window?
            let seven_day: Window?
        }
        guard let usage = try? JSONDecoder().decode(Usage.self, from: data) else { return nil }
        return CodexQuota(
            primaryPercent: usage.five_hour?.utilization ?? 0,
            secondaryPercent: usage.seven_day?.utilization ?? 0,
            planType: nil,
            asOf: Date()
        )
    }

    // MARK: - Credentials

    private static func accessToken() -> String? {
        let json = fileCredentials() ?? securityToolCredentials() ?? keychainCredentials()
        guard let json,
              let creds = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let oauth = creds["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        if let expiresAt = oauth["expiresAt"] as? Double,
           Date(timeIntervalSince1970: expiresAt / 1000) < Date() {
            return nil
        }
        return token
    }

    private static func keychainCredentials() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    /// Reads the credentials via /usr/bin/security. A GUI app double-clicked
    /// from Finder can't read another app's Keychain item directly (its ad-hoc
    /// identity isn't on the item's ACL, and a background-thread request is
    /// silently denied). The `security` tool is already trusted for this item,
    /// so shelling out to it succeeds without a password prompt.
    private static func securityToolCredentials() -> Data? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        task.standardOutput = out
        task.standardError = Pipe()
        do { try task.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let json = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !json.isEmpty else { return nil }
        return json.data(using: .utf8)
    }

    private static func fileCredentials() -> Data? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        return try? Data(contentsOf: url)
    }
}
