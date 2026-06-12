import Foundation

/// Reads the Claude subscription tier from ~/.claude.json's oauthAccount.
/// This is the accurate source (it distinguishes Max 5×/20×) and needs no
/// Keychain access — so the plan badge shows even when quota fetching is off.
enum ClaudeAccountReader {
    static func plan() -> PlanInfo? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = root["oauthAccount"] as? [String: Any] else { return nil }

        let userTier = account["userRateLimitTier"] as? String
        let orgTier = account["organizationRateLimitTier"] as? String
        let tier = (userTier?.isEmpty == false) ? userTier : orgTier
        return PlanCatalog.claude(rateLimitTier: tier,
                                  organizationType: account["organizationType"] as? String)
    }
}
