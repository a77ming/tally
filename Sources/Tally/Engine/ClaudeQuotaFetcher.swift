import Foundation
import Security

/// Fetches the official Claude subscription quota (5-hour and weekly windows)
/// from Anthropic's OAuth usage endpoint, authenticating with the credentials
/// Claude Code already stores in the Keychain. This is Tally's only network
/// call and can be disabled in Settings.
enum ClaudeQuotaFetcher {
    /// Returns the live 5h/weekly quota and the subscription plan. The plan is
    /// available from the stored credentials even when the network call fails.
    static func fetch() async -> (quota: CodexQuota?, plan: PlanInfo?) {
        let creds = credentials()
        let plan = PlanCatalog.claude(subscriptionType: creds?.subscriptionType,
                                      rateLimitTier: creds?.rateLimitTier)
        guard let token = creds?.token else { return (nil, plan) }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return (nil, plan) }

        struct Usage: Decodable {
            struct Window: Decodable { let utilization: Double? }
            let five_hour: Window?
            let seven_day: Window?
        }
        guard let usage = try? JSONDecoder().decode(Usage.self, from: data) else { return (nil, plan) }
        let quota = CodexQuota(
            primaryPercent: usage.five_hour?.utilization ?? 0,
            secondaryPercent: usage.seven_day?.utilization ?? 0,
            planType: nil,
            asOf: Date()
        )
        return (quota, plan)
    }

    // MARK: - Credentials

    private struct Credentials {
        let token: String?
        let subscriptionType: String?
        let rateLimitTier: String?
    }

    private static func credentials() -> Credentials? {
        let json = keychainCredentials() ?? fileCredentials()
        guard let json,
              let creds = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let oauth = creds["claudeAiOauth"] as? [String: Any] else { return nil }
        var token = oauth["accessToken"] as? String
        if let expiresAt = oauth["expiresAt"] as? Double,
           Date(timeIntervalSince1970: expiresAt / 1000) < Date() {
            token = nil
        }
        return Credentials(
            token: token,
            subscriptionType: oauth["subscriptionType"] as? String,
            rateLimitTier: oauth["rateLimitTier"] as? String
        )
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

    private static func fileCredentials() -> Data? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        return try? Data(contentsOf: url)
    }
}
