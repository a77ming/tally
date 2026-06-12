import Foundation

/// Aggregation key: one bucket per (local day, model, project).
struct BucketKey: Hashable {
    let day: String      // "2026-06-12", local time zone
    let model: String
    let project: String
}

struct UsageBucket {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0
    var requests = 0
    var cost = 0.0

    mutating func add(input: Int, output: Int, cacheRead: Int, cacheWrite: Int, cost: Double) {
        self.input += input
        self.output += output
        self.cacheRead += cacheRead
        self.cacheWrite += cacheWrite
        self.requests += 1
        self.cost += cost
    }

    var totalTokens: Int { input + output + cacheRead + cacheWrite }
}

struct UsageSnapshot: Sendable {
    var buckets: [BucketKey: UsageBucket] = [:]
    var sessionsByDay: [String: Set<String>] = [:]
    var lastUpdated: Date? = nil

    static let empty = UsageSnapshot()
}

extension BucketKey: Sendable {}
extension UsageBucket: Sendable {}

enum Period: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "7D"
    case month = "30D"
    case all = "All"

    var id: String { rawValue }

    /// Number of days covered, nil = unbounded.
    var days: Int? {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }
}

struct Totals {
    var cost = 0.0
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0
    var requests = 0
    var sessions = 0

    var totalTokens: Int { input + output + cacheRead + cacheWrite }
}

/// A row in the Models / Projects / Providers breakdown lists.
struct BreakdownRow: Identifiable {
    let id: String
    let name: String
    let detail: String?
    let colorHex: String?
    let isCurrent: Bool
    let cost: Double
    let tokens: Int

    init(id: String, name: String, detail: String? = nil, colorHex: String? = nil,
         isCurrent: Bool = false, cost: Double, tokens: Int) {
        self.id = id
        self.name = name
        self.detail = detail
        self.colorHex = colorHex
        self.isCurrent = isCurrent
        self.cost = cost
        self.tokens = tokens
    }
}

/// One slice of the daily chart: cost for (day, model).
struct DailySlice: Identifiable {
    var id: String { day + model }
    let day: String
    let date: Date
    let model: String
    let cost: Double
}
