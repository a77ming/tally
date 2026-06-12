import Foundation

/// Reads the Codex plan tier from ~/.codex/auth.json by decoding the
/// id_token JWT's `chatgpt_plan_type` claim. Purely local, no network.
enum CodexAuthReader {
    static func plan() -> PlanInfo? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        var idToken: String?
        if let tokens = root["tokens"] as? [String: Any] {
            idToken = tokens["id_token"] as? String
        } else if let s = root["tokens"] as? String {
            idToken = s
        }
        guard let jwt = idToken else { return nil }

        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }

        guard let payload = Data(base64Encoded: b64),
              let claims = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let auth = claims["https://api.openai.com/auth"] as? [String: Any]
        else { return nil }
        return PlanCatalog.codex(planType: auth["chatgpt_plan_type"] as? String)
    }
}
