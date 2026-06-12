import Foundation

/// A provider configured in cc-switch.
struct ProviderInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let category: String?
    let isCurrent: Bool
    let colorHex: String?
    let sortIndex: Int
}

/// One row of cc-switch's usage_daily_rollups table.
struct ProviderRollup: Sendable {
    let date: String        // "2026-06-12"
    let providerId: String  // may be "_session" (unattributed proxy log)
    let model: String
    let requests: Int
    let input: Int
    let output: Int
    let cacheRead: Int
    let cacheWrite: Int
    let cost: Double

    var totalTokens: Int { input + output + cacheRead + cacheWrite }
}

struct CCSwitchData: Sendable {
    var providers: [ProviderInfo] = []
    var rollups: [ProviderRollup] = []
    var pricing: [String: ModelPrice] = [:]
}
