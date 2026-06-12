import Foundation

/// A subscription tier and its monthly price, for the "what plan are you on"
/// badge. Prices are USD/month from each vendor's public pricing (2026).
struct PlanInfo: Sendable, Equatable {
    let label: String
    let monthlyUSD: Int?   // nil = custom / unknown (Enterprise etc.)
}

enum PlanCatalog {
    /// Claude subscription, from the Keychain OAuth credentials
    /// (`subscriptionType` + `rateLimitTier`).
    static func claude(subscriptionType: String?, rateLimitTier: String?) -> PlanInfo? {
        guard let sub = subscriptionType?.lowercased(), !sub.isEmpty else { return nil }
        let tier = (rateLimitTier ?? "").lowercased()
        switch sub {
        case "free": return PlanInfo(label: "Free", monthlyUSD: 0)
        case "pro": return PlanInfo(label: "Pro", monthlyUSD: 20)
        case "max":
            if tier.contains("20x") { return PlanInfo(label: "Max 20×", monthlyUSD: 200) }
            if tier.contains("5x") { return PlanInfo(label: "Max 5×", monthlyUSD: 100) }
            return PlanInfo(label: "Max", monthlyUSD: 100)
        case "team": return PlanInfo(label: "Team", monthlyUSD: 30)
        case "enterprise": return PlanInfo(label: "Enterprise", monthlyUSD: nil)
        default: return PlanInfo(label: sub.capitalized, monthlyUSD: nil)
        }
    }

    /// ChatGPT / Codex plan, from the id_token's `chatgpt_plan_type`.
    static func codex(planType: String?) -> PlanInfo? {
        guard let p = planType?.lowercased(), !p.isEmpty, p != "unknown" else { return nil }
        switch p {
        case "free": return PlanInfo(label: "Free", monthlyUSD: 0)
        case "go": return PlanInfo(label: "Go", monthlyUSD: 8)
        case "plus": return PlanInfo(label: "Plus", monthlyUSD: 20)
        case "prolite", "pro_lite", "pro-lite": return PlanInfo(label: "Pro Lite", monthlyUSD: 100)
        case "pro": return PlanInfo(label: "Pro", monthlyUSD: 200)
        case "business", "team": return PlanInfo(label: "Business", monthlyUSD: 30)
        case "enterprise": return PlanInfo(label: "Enterprise", monthlyUSD: nil)
        default: return PlanInfo(label: p.capitalized, monthlyUSD: nil)
        }
    }
}
