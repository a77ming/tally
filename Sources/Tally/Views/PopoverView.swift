import AppKit
import Charts
import SwiftUI

private let accent = Color(hex: "#D97757")

struct PopoverView: View {
    @ObservedObject var store: StatsStore
    @AppStorage("appLanguage") private var appLanguage = "system"

    private enum Tab: String, CaseIterable, Identifiable {
        case apps = "Apps"
        case models = "Models"
        case projects = "Projects"
        case providers = "Providers"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .models

    var body: some View {
        let _ = appLanguage
        VStack(alignment: .leading, spacing: 13) {
            header
            hero
            quotaSection
            chart
            Divider()
            tabPicker
            // Constant height keeps the MenuBarExtra window size static —
            // dynamic content height leaves a stale gap when the window
            // doesn't shrink back after a resize.
            breakdownList
                .frame(height: 190, alignment: .top)
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(width: 340)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Picker("", selection: $store.period) {
                ForEach(Period.allCases) { p in
                    Text(L10n.t(p.rawValue)).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Menu {
                Button(L10n.t("Refresh")) { store.refresh() }
                    .keyboardShortcut("r")
                SettingsLink {
                    Text(L10n.t("Settings…"))
                }
                Divider()
                Button(L10n.t("Quit Tally")) { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        let totals = store.totals(for: store.period)
        return VStack(alignment: .leading, spacing: 3) {
            Text(Formatters.cost(totals.cost))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(L10n.f("%@ tokens · %d requests · %d sessions",
                        Formatters.tokens(totals.totalTokens), totals.requests, totals.sessions))
                .font(.caption)
                .foregroundStyle(.secondary)
            // Always exactly one line here — hiding it changes the content
            // height and the MenuBarExtra window leaves a stale gap.
            let insight = insightText(totals: totals)
            Text(insight.text)
                .font(.caption)
                .foregroundStyle(insight.color)
        }
    }

    private func insightText(totals: Totals) -> (text: String, color: Color) {
        switch store.period {
        case .today:
            let yesterday = store.yesterdayCost()
            guard yesterday > 0 else { return ("—", .secondary) }
            let pct = Int((abs(totals.cost - yesterday) / yesterday * 100).rounded())
            return totals.cost >= yesterday
                ? (L10n.f("▲ %d%% vs yesterday", pct), .red)
                : (L10n.f("▼ %d%% vs yesterday", pct), .green)
        case .week:
            return (L10n.f("%@/day average", Formatters.cost(totals.cost / 7)), .secondary)
        case .month:
            return (L10n.f("%@/day average", Formatters.cost(totals.cost / 30)), .secondary)
        case .all:
            let days = max(1, store.activeDayCount())
            return (L10n.f("%1$@/day over %2$d active days",
                           Formatters.cost(totals.cost / Double(days)), days), .secondary)
        }
    }

    // MARK: - Rate limits

    @ViewBuilder
    private var quotaSection: some View {
        // A row shows whenever we know the plan (from local files) OR have
        // live quota — so the plan badge appears even before Keychain auth.
        let showClaude = store.claudePlan != nil || store.claudeQuota != nil
        let showCodex = store.codexPlan != nil || store.snapshot.codexQuota != nil
        if showClaude || showCodex {
            VStack(alignment: .leading, spacing: 12) {
                if showClaude {
                    QuotaRow(name: "Claude Code", colorHex: "#D97757",
                             quota: store.claudeQuota, plan: store.claudePlan,
                             needsAuth: store.claudeQuota == nil)
                }
                if showClaude && showCodex {
                    Divider()
                }
                if showCodex {
                    QuotaRow(name: "Codex", colorHex: "#10A37F",
                             quota: store.snapshot.codexQuota, plan: store.codexPlan,
                             needsAuth: false)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Chart

    private var chart: some View {
        let slices = store.dailySlices(days: 14).filter { !$0.model.isEmpty && $0.cost > 0 }
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(byAdding: .day, value: -13, to: today) ?? today
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        return Chart(slices) { slice in
            BarMark(
                x: .value("Day", slice.date, unit: .day),
                y: .value("Cost", slice.cost)
            )
            .foregroundStyle(by: .value("Model", slice.model))
            .cornerRadius(2)
            .opacity(slice.date == today ? 1 : 0.55)
        }
        .chartXScale(domain: start...end)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.day(), centered: true)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 2)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel()
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .chartLegend(position: .bottom, spacing: 4)
        .frame(height: 96)
    }

    // MARK: - Tabs

    private var tabPicker: some View {
        Picker("", selection: $tab) {
            ForEach(Tab.allCases) { t in
                Text(L10n.t(t.rawValue)).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
    }

    // MARK: - Breakdown list

    private var rows: [BreakdownRow] {
        switch tab {
        case .apps: return store.appRows()
        case .models: return store.modelRows()
        case .projects: return store.projectRows()
        case .providers: return store.providerRows()
        }
    }

    @ViewBuilder
    private var breakdownList: some View {
        let rows = rows
        if tab == .providers && rows.isEmpty {
            VStack(spacing: 4) {
                Text(L10n.t("cc-switch not detected"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(L10n.t("Install cc-switch to track per-provider usage."))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else if rows.isEmpty {
            Text(L10n.t("No usage in this period"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            let maxCost = rows.map(\.cost).max() ?? 0
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        BreakdownRowView(row: row, maxCost: maxCost,
                                         dimmed: tab == .providers && row.tokens == 0)
                    }
                    if tab == .providers {
                        Text(L10n.t("usage via cc-switch proxy logs"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(updatedText)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)
            } else {
                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var updatedText: String {
        if let date = store.snapshot.lastUpdated {
            return L10n.f("Updated %@", Formatters.relativeTime(date))
        }
        return L10n.t("Updating…")
    }
}

private struct BreakdownRowView: View {
    let row: BreakdownRow
    let maxCost: Double
    let dimmed: Bool
    @AppStorage("appLanguage") private var appLanguage = "system"

    var body: some View {
        let _ = appLanguage
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                if let hex = row.colorHex {
                    Circle()
                        .fill(row.isCurrent ? accent : Color(hex: hex))
                        .frame(width: 8, height: 8)
                }
                Text(row.name)
                    .font(.body)
                    .lineLimit(1)
                if row.isCurrent {
                    Text(L10n.t("ACTIVE"))
                        .font(.system(size: 8, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(accent)
                }
                if let detail = row.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Formatters.cost(row.cost))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                    Text(Formatters.tokens(row.tokens))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accent.opacity(0.8))
                        .frame(width: geo.size.width * share)
                }
            }
            .frame(height: 3)
        }
        .opacity(dimmed ? 0.45 : 1)
    }

    private var share: Double {
        maxCost > 0 ? min(1, row.cost / maxCost) : 0
    }
}

/// One app's rate limits as a full-width row: header (name + ranked plan
/// badge) over two big gauges.
private struct QuotaRow: View {
    let name: String
    let colorHex: String
    let quota: CodexQuota?
    let plan: PlanInfo?
    let needsAuth: Bool

    var body: some View {
        let tint = Color(hex: colorHex)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if let plan {
                    PlanBadge(plan: plan)
                }
            }
            if let quota {
                QuotaGauge(label: "5h", percent: quota.primaryPercent)
                QuotaGauge(label: "7d", percent: quota.secondaryPercent)
            } else if needsAuth {
                Text(L10n.t("Approve Keychain access to show usage limits"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// A ranked subscription badge — bronze→diamond by monthly spend, with a
/// crown on the top tier. The quiet flex.
private struct PlanBadge: View {
    let plan: PlanInfo

    var body: some View {
        let rank = PlanRank.of(plan.monthlyUSD)
        HStack(spacing: 4) {
            if let icon = rank.icon {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
            }
            Text(plan.label)
                .font(.system(size: 11, weight: .heavy))
            if let price = Formatters.planPrice(plan) {
                Text(price)
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.92)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3.5)
        .foregroundStyle(rank.foreground)
        .background(rank.fill, in: Capsule())
        .overlay(Capsule().strokeBorder(rank.stroke, lineWidth: 0.75))
        .shadow(color: rank.glow, radius: rank.glowRadius, y: 0)
    }
}

/// Visual tier for a plan, keyed off monthly price.
private struct PlanRank {
    let fill: AnyShapeStyle
    let foreground: Color
    let stroke: Color
    let glow: Color
    let glowRadius: CGFloat
    let icon: String?

    static func of(_ usd: Int?) -> PlanRank {
        // Enterprise / unknown → sleek graphite.
        guard let usd else {
            return PlanRank(fill: AnyShapeStyle(Color(hex: "#3A3A3C")),
                            foreground: .white, stroke: .white.opacity(0.25),
                            glow: .clear, glowRadius: 0, icon: "building.2.fill")
        }
        switch usd {
        case 0:  // Free → bronze
            return PlanRank(fill: AnyShapeStyle(Color(hex: "#8D6E63").opacity(0.18)),
                            foreground: Color(hex: "#8D6E63"), stroke: Color(hex: "#8D6E63").opacity(0.4),
                            glow: .clear, glowRadius: 0, icon: nil)
        case 1...20:  // Plus / Pro → silver-blue
            return PlanRank(fill: AnyShapeStyle(grad("#7FB0E0", "#5C8FD6")),
                            foreground: .white, stroke: .white.opacity(0.4),
                            glow: Color(hex: "#5C8FD6").opacity(0.35), glowRadius: 2.5, icon: nil)
        case 21...100:  // Max 5× / Pro Lite → amethyst
            return PlanRank(fill: AnyShapeStyle(grad("#A368E0", "#7B3FC4")),
                            foreground: .white, stroke: .white.opacity(0.5),
                            glow: Color(hex: "#7B3FC4").opacity(0.45), glowRadius: 4, icon: "sparkles")
        default:  // $200 → gold/diamond, crowned
            return PlanRank(fill: AnyShapeStyle(grad("#FFD86B", "#F0A93B")),
                            foreground: Color(hex: "#5A3A00"), stroke: .white.opacity(0.7),
                            glow: Color(hex: "#FFC23C").opacity(0.6), glowRadius: 5, icon: "crown.fill")
        }
    }

    private static func grad(_ a: String, _ b: String) -> LinearGradient {
        LinearGradient(colors: [Color(hex: a), Color(hex: b)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// One rate-limit gauge: "5h ▓▓▓░░░░░ 37%" — full width, prominent percentage.
private struct QuotaGauge: View {
    let label: String
    let percent: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                GeometryReader { geo in
                    Capsule().fill(color)
                        .frame(width: max(4, geo.size.width * min(1, percent / 100)))
                }
            }
            .frame(height: 9)
            Text("\(Int(percent.rounded()))%")
                .font(.body.weight(.bold))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var color: Color {
        switch percent {
        case ..<50: return .green
        case ..<80: return .orange
        default: return .red
        }
    }
}
