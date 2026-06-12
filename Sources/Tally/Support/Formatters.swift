import Foundation
import SwiftUI

enum Formatters {
    /// "12.4M", "843K", "512" — 1 decimal, trailing .0 trimmed.
    static func tokens(_ n: Int) -> String {
        let v = Double(n)
        func short(_ x: Double, _ suffix: String) -> String {
            let s = String(format: "%.1f", x)
            let trimmed = s.hasSuffix(".0") ? String(s.dropLast(2)) : s
            return trimmed + suffix
        }
        if v >= 1_000_000_000 { return short(v / 1_000_000_000, "B") }
        if v >= 1_000_000 { return short(v / 1_000_000, "M") }
        if v >= 1_000 { return short(v / 1_000, "K") }
        return String(n)
    }

    /// ">= 100 → $123, >= 1 → $12.34, > 0 → $0.04, 0 → $0.00"
    static func cost(_ d: Double) -> String {
        if d >= 100 { return String(format: "$%.0f", d) }
        if d > 0 { return String(format: "$%.2f", d) }
        return "$0.00"
    }

    /// "claude-opus-4-7" → "Opus 4.7"; "claude-sonnet-4-6-20260217" → "Sonnet 4.6";
    /// non-claude ids pass through (date suffix stripped).
    static func modelDisplayName(_ id: String) -> String {
        var name = id
        // Strip trailing -YYYYMMDD date suffix.
        if let range = name.range(of: #"-\d{8}$"#, options: .regularExpression) {
            name.removeSubrange(range)
        }
        if name.lowercased().hasPrefix("gpt-") {
            return "GPT" + name.dropFirst("gpt".count)
        }
        guard name.lowercased().hasPrefix("claude-") else { return name }
        let parts = name.dropFirst("claude-".count).split(separator: "-").map(String.init)
        let words = parts.filter { Int($0) == nil }
        let numbers = parts.filter { Int($0) != nil }
        guard !words.isEmpty else { return name }
        let display = words.map(\.capitalized).joined(separator: " ")
        let version = numbers.joined(separator: ".")
        return version.isEmpty ? display : display + " " + version
    }

    /// Localized monthly price: "$20/mo" / "$20/月", or "Free" / "免费".
    /// nil when the plan price is unknown (Enterprise/custom).
    static func planPrice(_ plan: PlanInfo) -> String? {
        guard let m = plan.monthlyUSD else { return nil }
        return m == 0 ? L10n.t("Free") : L10n.f("$%d/mo", m)
    }

    static func categoryLabel(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        switch s {
        case "official": return "Official"
        case "cn_official": return "CN Official"
        case "third_party": return "Third-party"
        case "aggregator": return "Aggregator"
        case "custom": return "Custom"
        default: return s.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// "just now", "2m ago", "3h ago", "5d ago" (localized)
    static func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return L10n.t("just now") }
        if seconds < 3600 { return L10n.f("%dm ago", seconds / 60) }
        if seconds < 86400 { return L10n.f("%dh ago", seconds / 3600) }
        return L10n.f("%dd ago", seconds / 86400)
    }
}

extension Color {
    /// Color from "#D97757" style hex strings; falls back to gray.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&value) else {
            self = .gray
            return
        }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
