import Foundation
import SwiftUI

@MainActor
final class StatsStore: ObservableObject {
    @Published var snapshot = UsageSnapshot.empty
    @Published var providers: [ProviderInfo] = []
    @Published var rollups: [ProviderRollup] = []
    @Published var period: Period = .today
    @Published var isRefreshing = false

    @AppStorage("refreshInterval") var refreshInterval: Int = 60

    private let indexer = UsageIndexer()
    private var timerTask: Task<Void, Never>?
    private var pricingLoaded = false

    init() {
        startTimer()
        refresh()
    }

    func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.refreshInterval ?? 60
                try? await Task.sleep(for: .seconds(max(15, interval)))
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task.detached(priority: .utility) { [indexer, pricingLoaded] in
            let ccswitch = CCSwitchStore.load()
            if !pricingLoaded {
                var pricing = Pricing(exact: ccswitch?.pricing ?? [:])
                // cc-switch sometimes has 0-cost placeholder rows; drop them
                // so built-in fallbacks apply.
                pricing.exact = pricing.exact.filter { $0.value.input > 0 || $0.value.output > 0 }
                await indexer.updatePricing(pricing)
            }
            let snap = await indexer.scan()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.snapshot = snap
                if let cc = ccswitch {
                    self.providers = cc.providers
                    self.rollups = cc.rollups
                }
                self.pricingLoaded = true
                self.isRefreshing = false
            }
        }
    }

    // MARK: - Period filtering

    /// Days (yyyy-MM-dd) included in the current period; nil = all.
    private func dayRange(for period: Period) -> ClosedRange<String>? {
        guard let days = period.days else { return nil }
        let cal = Calendar.current
        let end = UsageIndexer.dayFormatter.string(from: Date())
        let start = UsageIndexer.dayFormatter.string(
            from: cal.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date())
        return start...end
    }

    private func contains(_ day: String, _ range: ClosedRange<String>?) -> Bool {
        guard let range else { return true }
        return range.contains(day)
    }

    func totals(for period: Period) -> Totals {
        let range = dayRange(for: period)
        var t = Totals()
        for (key, b) in snapshot.buckets where contains(key.day, range) {
            t.cost += b.cost
            t.input += b.input
            t.output += b.output
            t.cacheRead += b.cacheRead
            t.cacheWrite += b.cacheWrite
            t.requests += b.requests
        }
        t.sessions = snapshot.sessionsByDay
            .filter { contains($0.key, range) }
            .reduce(0) { $0 + $1.value.count }
        return t
    }

    /// Distinct days with any recorded usage, for the all-time daily average.
    func activeDayCount() -> Int {
        Set(snapshot.buckets.keys.map(\.day)).count
    }

    /// Yesterday's totals, for the "vs yesterday" delta on the Today view.
    func yesterdayCost() -> Double {
        let day = UsageIndexer.dayFormatter.string(
            from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        return snapshot.buckets
            .filter { $0.key.day == day }
            .reduce(0) { $0 + $1.value.cost }
    }

    func modelRows() -> [BreakdownRow] {
        let range = dayRange(for: period)
        var agg: [String: (cost: Double, tokens: Int)] = [:]
        for (key, b) in snapshot.buckets where contains(key.day, range) {
            agg[key.model, default: (0, 0)].cost += b.cost
            agg[key.model, default: (0, 0)].tokens += b.totalTokens
        }
        return agg
            .map { BreakdownRow(id: $0.key, name: Formatters.modelDisplayName($0.key),
                                cost: $0.value.cost, tokens: $0.value.tokens) }
            .sorted { $0.cost == $1.cost ? $0.tokens > $1.tokens : $0.cost > $1.cost }
    }

    func projectRows() -> [BreakdownRow] {
        let range = dayRange(for: period)
        var agg: [String: (cost: Double, tokens: Int)] = [:]
        for (key, b) in snapshot.buckets where contains(key.day, range) {
            agg[key.project, default: (0, 0)].cost += b.cost
            agg[key.project, default: (0, 0)].tokens += b.totalTokens
        }
        return agg
            .map { BreakdownRow(id: $0.key, name: $0.key,
                                cost: $0.value.cost, tokens: $0.value.tokens) }
            .sorted { $0.cost == $1.cost ? $0.tokens > $1.tokens : $0.cost > $1.cost }
    }

    /// Per-provider usage out of cc-switch rollups. Rows logged by the
    /// session-log sync carry provider_id "_session"; those are attributed to
    /// a provider by fuzzy-matching the model name against provider names.
    func providerRows() -> [BreakdownRow] {
        let range = dayRange(for: period)
        let byId = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })

        var agg: [String: (cost: Double, tokens: Int)] = [:]
        for r in rollups where contains(r.date, range) {
            let pid = resolveProvider(for: r, byId: byId)
            agg[pid, default: (0, 0)].cost += r.cost
            agg[pid, default: (0, 0)].tokens += r.totalTokens
        }

        var rows: [BreakdownRow] = []
        for p in providers {
            let v = agg[p.id]
            rows.append(BreakdownRow(id: p.id, name: p.name,
                                     detail: Formatters.categoryLabel(p.category),
                                     colorHex: p.colorHex, isCurrent: p.isCurrent,
                                     cost: v?.cost ?? 0, tokens: v?.tokens ?? 0))
        }
        if let other = agg["_other"], other.tokens > 0 {
            rows.append(BreakdownRow(id: "_other", name: "Unattributed",
                                     cost: other.cost, tokens: other.tokens))
        }
        return rows.sorted {
            if $0.isCurrent != $1.isCurrent { return $0.isCurrent }
            return $0.tokens > $1.tokens
        }
    }

    private func resolveProvider(for r: ProviderRollup, byId: [String: ProviderInfo]) -> String {
        if byId[r.providerId] != nil { return r.providerId }
        let model = r.model.lowercased().filter(\.isLetter)
        // Claude models routed through the session log belong to whichever
        // provider is the official one, if configured.
        if model.contains("claude") {
            if let official = providers.first(where: { ($0.category ?? "") == "official" }) {
                return official.id
            }
        }
        for p in providers {
            let name = p.name.lowercased().filter(\.isLetter)
            guard name.count >= 3 else { continue }
            if model.contains(name) || name.contains(model) { return p.id }
        }
        return "_other"
    }

    // MARK: - Chart

    /// Daily cost slices for the last `days` days, stacked by model
    /// (top models by cost, the rest folded into "Other").
    func dailySlices(days: Int = 14, maxModels: Int = 5) -> [DailySlice] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var dayList: [(String, Date)] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            let d = cal.date(byAdding: .day, value: -i, to: today) ?? today
            dayList.append((UsageIndexer.dayFormatter.string(from: d), d))
        }
        let daySet = Set(dayList.map(\.0))

        var costByModel: [String: Double] = [:]
        for (key, b) in snapshot.buckets where daySet.contains(key.day) {
            costByModel[key.model, default: 0] += b.cost
        }
        let top = Set(costByModel.sorted { $0.value > $1.value }.prefix(maxModels).map(\.key))

        var agg: [String: [String: Double]] = [:]  // day -> displayModel -> cost
        for (key, b) in snapshot.buckets where daySet.contains(key.day) {
            let label = top.contains(key.model) ? Formatters.modelDisplayName(key.model) : "Other"
            agg[key.day, default: [:]][label, default: 0] += b.cost
        }

        var slices: [DailySlice] = []
        for (day, date) in dayList {
            if let models = agg[day] {
                for (model, cost) in models.sorted(by: { $0.key < $1.key }) {
                    slices.append(DailySlice(day: day, date: date, model: model, cost: cost))
                }
            } else {
                slices.append(DailySlice(day: day, date: date, model: "", cost: 0))
            }
        }
        return slices
    }
}
