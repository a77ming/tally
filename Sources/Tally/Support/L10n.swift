import Foundation

/// In-code localization (no Xcode, so no string catalogs).
/// Key = the English string itself. Missing key → returned unchanged.
enum L10n {
    static func t(_ key: String) -> String {
        guard let entry = table[key] else { return key }
        return resolvedLanguage() == "zh" ? entry.zh : entry.en
    }

    static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    private static func resolvedLanguage() -> String {
        let pref = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        if pref == "system" {
            return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh" : "en"
        }
        return pref
    }

    private static let table: [String: (en: String, zh: String)] = [
        // Periods
        "Today": ("Today", "今天"),
        "7D": ("7D", "7天"),
        "30D": ("30D", "30天"),
        "All": ("All", "全部"),
        // Tabs
        "Apps": ("Apps", "应用"),
        "Free": ("Free", "免费"),
        "Approve Keychain access to show usage limits":
            ("Approve Keychain access to show usage limits", "授权钥匙串后显示用量限额"),
        "$%d/mo": ("$%d/mo", "$%d/月"),
        "Rate Limits": ("Rate Limits", "限额"),
        "Models": ("Models", "模型"),
        "Projects": ("Projects", "项目"),
        "Providers": ("Providers", "供应商"),
        // Hero
        "%@ tokens · %d requests · %d sessions":
            ("%@ tokens · %d requests · %d sessions", "%@ tokens · %d 次请求 · %d 个会话"),
        "▲ %d%% vs yesterday": ("▲ %d%% vs yesterday", "▲ 比昨天多 %d%%"),
        "▼ %d%% vs yesterday": ("▼ %d%% vs yesterday", "▼ 比昨天少 %d%%"),
        "%@/day average": ("%@/day average", "日均 %@"),
        "%1$@/day over %2$d active days":
            ("%1$@/day over %2$d active days", "%2$d 个活跃日 · 日均 %1$@"),
        // Breakdown
        "ACTIVE": ("ACTIVE", "当前"),
        "No usage in this period": ("No usage in this period", "该时段无用量"),
        "cc-switch not detected": ("cc-switch not detected", "未检测到 cc-switch"),
        "Install cc-switch to track per-provider usage.":
            ("Install cc-switch to track per-provider usage.", "安装 cc-switch 即可按供应商查看用量。"),
        "usage via cc-switch proxy logs":
            ("usage via cc-switch proxy logs", "数据来自 cc-switch 代理日志"),
        // Menu
        "Refresh": ("Refresh", "刷新"),
        "Settings…": ("Settings…", "设置…"),
        "Quit Tally": ("Quit Tally", "退出 Tally"),
        // Footer
        "Updated %@": ("Updated %@", "%@更新"),
        "Updating…": ("Updating…", "更新中…"),
        "just now": ("just now", "刚刚"),
        "%dm ago": ("%dm ago", "%d 分钟前"),
        "%dh ago": ("%dh ago", "%d 小时前"),
        "%dd ago": ("%dd ago", "%d 天前"),
        // Settings
        "Menu Bar": ("Menu Bar", "菜单栏"),
        "Show": ("Show", "显示"),
        "Cost": ("Cost", "花费"),
        "Tokens": ("Tokens", "Token 数"),
        "Icon only": ("Icon only", "仅图标"),
        "Refresh every": ("Refresh every", "刷新间隔"),
        "30 seconds": ("30 seconds", "30 秒"),
        "1 minute": ("1 minute", "1 分钟"),
        "5 minutes": ("5 minutes", "5 分钟"),
        "General": ("General", "通用"),
        "Launch at Login": ("Launch at Login", "开机自启"),
        "Language": ("Language", "语言"),
        "System": ("System", "跟随系统"),
        "Quota": ("Quota", "限额"),
        "Show Claude subscription quota":
            ("Show Claude subscription quota", "显示 Claude 订阅限额"),
        "Queries Anthropic's usage endpoint with the credentials Claude Code already stores — Tally's only network call. The first time, approve the Keychain prompt (Always Allow). Codex quota comes from local logs, no prompt.":
            ("Queries Anthropic's usage endpoint with the credentials Claude Code already stores — Tally's only network call. The first time, approve the Keychain prompt (Always Allow). Codex quota comes from local logs, no prompt.",
             "使用 Claude Code 已保存的凭证查询 Anthropic 官方用量接口——这是 Tally 唯一的网络请求。首次会弹出钥匙串授权框，点“始终允许”即可。Codex 限额来自本地日志，无需授权。"),
        "Data": ("Data", "数据"),
        "Claude logs": ("Claude logs", "Claude 日志"),
        "Codex logs": ("Codex logs", "Codex 日志"),
    ]
}
