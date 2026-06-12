import Foundation
import SQLite3

/// Read-only access to cc-switch's SQLite database (~/.cc-switch/cc-switch.db).
/// Everything here is optional: if cc-switch isn't installed, the app simply
/// hides the Providers tab content and uses built-in pricing.
enum CCSwitchStore {
    static let dbPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cc-switch/cc-switch.db").path

    static func load() -> CCSwitchData? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            if db != nil { sqlite3_close(db) }
            return nil
        }
        defer { sqlite3_close(db) }

        var data = CCSwitchData()
        data.providers = loadProviders(db)
        data.rollups = loadRollups(db)
        data.pricing = loadPricing(db)
        return data
    }

    private static func loadProviders(_ db: OpaquePointer) -> [ProviderInfo] {
        query(db, """
            SELECT id, name, category, is_current, icon_color, COALESCE(sort_index, 9999)
            FROM providers WHERE app_type = 'claude' ORDER BY is_current DESC, sort_index
            """) { stmt in
            ProviderInfo(
                id: text(stmt, 0) ?? "",
                name: text(stmt, 1) ?? "?",
                category: text(stmt, 2),
                isCurrent: sqlite3_column_int(stmt, 3) == 1,
                colorHex: text(stmt, 4),
                sortIndex: Int(sqlite3_column_int(stmt, 5))
            )
        }
    }

    private static func loadRollups(_ db: OpaquePointer) -> [ProviderRollup] {
        query(db, """
            SELECT date, provider_id, model, request_count, input_tokens, output_tokens,
                   cache_read_tokens, cache_creation_tokens, total_cost_usd
            FROM usage_daily_rollups WHERE app_type = 'claude'
            """) { stmt in
            ProviderRollup(
                date: text(stmt, 0) ?? "",
                providerId: text(stmt, 1) ?? "",
                model: text(stmt, 2) ?? "",
                requests: Int(sqlite3_column_int64(stmt, 3)),
                input: Int(sqlite3_column_int64(stmt, 4)),
                output: Int(sqlite3_column_int64(stmt, 5)),
                cacheRead: Int(sqlite3_column_int64(stmt, 6)),
                cacheWrite: Int(sqlite3_column_int64(stmt, 7)),
                cost: Double(text(stmt, 8) ?? "0") ?? 0
            )
        }
    }

    private static func loadPricing(_ db: OpaquePointer) -> [String: ModelPrice] {
        let rows: [(String, ModelPrice)] = query(db, """
            SELECT model_id, input_cost_per_million, output_cost_per_million,
                   cache_read_cost_per_million, cache_creation_cost_per_million
            FROM model_pricing
            """) { stmt in
            (
                (text(stmt, 0) ?? "").lowercased(),
                ModelPrice(
                    input: Double(text(stmt, 1) ?? "0") ?? 0,
                    output: Double(text(stmt, 2) ?? "0") ?? 0,
                    cacheRead: Double(text(stmt, 3) ?? "0") ?? 0,
                    cacheWrite: Double(text(stmt, 4) ?? "0") ?? 0
                )
            )
        }
        return Dictionary(rows, uniquingKeysWith: { a, _ in a })
    }

    // MARK: - SQLite helpers

    private static func query<T>(_ db: OpaquePointer, _ sql: String,
                                 row: (OpaquePointer) -> T) -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(row(stmt))
        }
        return out
    }

    private static func text(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: c)
    }
}
