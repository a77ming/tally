import Foundation

/// USD per million tokens.
struct ModelPrice: Sendable {
    let input: Double
    let output: Double
    let cacheRead: Double
    let cacheWrite: Double
}

struct Pricing: Sendable {
    /// Exact model id (lowercased) -> price. Seeded from cc-switch's
    /// model_pricing table when available, merged over built-in defaults.
    var exact: [String: ModelPrice]

    /// Built-in fallbacks matched by substring, checked in order.
    static let fallbacks: [(pattern: String, price: ModelPrice)] = [
        ("claude-fable", ModelPrice(input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25)),
        ("claude-mythos", ModelPrice(input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25)),
        ("claude-opus-4-1", ModelPrice(input: 15, output: 75, cacheRead: 1.5, cacheWrite: 18.75)),
        ("claude-opus-4-2", ModelPrice(input: 15, output: 75, cacheRead: 1.5, cacheWrite: 18.75)),
        ("claude-opus", ModelPrice(input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25)),
        ("claude-sonnet", ModelPrice(input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75)),
        ("claude-haiku", ModelPrice(input: 1, output: 5, cacheRead: 0.1, cacheWrite: 1.25)),
        ("claude-3-5-haiku", ModelPrice(input: 0.8, output: 4, cacheRead: 0.08, cacheWrite: 1)),
        ("gpt-5-mini", ModelPrice(input: 0.25, output: 2, cacheRead: 0.025, cacheWrite: 0)),
        ("gpt-5-nano", ModelPrice(input: 0.05, output: 0.4, cacheRead: 0.005, cacheWrite: 0)),
        ("gpt-5", ModelPrice(input: 1.25, output: 10, cacheRead: 0.125, cacheWrite: 0)),
        ("gpt-4.1", ModelPrice(input: 2, output: 8, cacheRead: 0.5, cacheWrite: 0)),
        ("minimax", ModelPrice(input: 0.3, output: 1.2, cacheRead: 0.03, cacheWrite: 0.375)),
        ("kimi", ModelPrice(input: 0.6, output: 2.5, cacheRead: 0.06, cacheWrite: 0.75)),
        ("deepseek", ModelPrice(input: 0.28, output: 0.42, cacheRead: 0.028, cacheWrite: 0.35)),
        ("glm", ModelPrice(input: 0.6, output: 2.2, cacheRead: 0.06, cacheWrite: 0.75)),
    ]

    func price(for model: String) -> ModelPrice? {
        let key = model.lowercased()
        if let p = exact[key] { return p }
        // Prefix match against exact table (handles dated ids like
        // "claude-sonnet-4-6" vs "claude-sonnet-4-6-20260217").
        if let hit = exact.first(where: { key.hasPrefix($0.key) || $0.key.hasPrefix(key) }) {
            return hit.value
        }
        return Self.fallbacks.first { key.contains($0.pattern) }?.price
    }

    func cost(model: String, input: Int, output: Int, cacheRead: Int, cacheWrite: Int) -> Double {
        guard let p = price(for: model) else { return 0 }
        return (Double(input) * p.input
            + Double(output) * p.output
            + Double(cacheRead) * p.cacheRead
            + Double(cacheWrite) * p.cacheWrite) / 1_000_000
    }
}
