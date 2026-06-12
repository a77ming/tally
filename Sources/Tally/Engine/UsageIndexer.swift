import Foundation

/// Incrementally scans ~/.claude/projects/**/*.jsonl and aggregates token
/// usage into per-(day, model, project) buckets. Files are tracked by byte
/// offset so refreshes only parse appended data.
actor UsageIndexer {
    private struct FileState {
        var size: Int
        var offset: Int
    }

    private var files: [String: FileState] = [:]
    private var seen: Set<String> = []   // "messageId|requestId" dedup
    private var buckets: [BucketKey: UsageBucket] = [:]
    private var sessionsByDay: [String: Set<String>] = [:]

    private let root: URL
    private var pricing: Pricing

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects"),
         pricing: Pricing = Pricing(exact: [:])) {
        self.root = root
        self.pricing = pricing
    }

    func updatePricing(_ pricing: Pricing) {
        self.pricing = pricing
        // Pricing changes require a full re-aggregation.
        files = [:]
        seen = []
        buckets = [:]
        sessionsByDay = [:]
    }

    func scan() -> UsageSnapshot {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey],
                                             options: [.skipsHiddenFiles]) else {
            return snapshot()
        }
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let path = url.path
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var state = files[path] ?? FileState(size: 0, offset: 0)
            if size < state.offset {
                // File was truncated/rewritten — rescan from the top. Buckets
                // from the old content can't be removed cheaply; duplicates
                // are still caught by the message-id dedup set.
                state.offset = 0
            }
            if size > state.offset {
                parse(file: url, from: state.offset)
                state.offset = size
            }
            state.size = size
            files[path] = state
        }
        return snapshot()
    }

    private func snapshot() -> UsageSnapshot {
        UsageSnapshot(buckets: buckets, sessionsByDay: sessionsByDay, lastUpdated: Date())
    }

    // MARK: - Parsing

    private struct LogLine: Decodable {
        let type: String?
        let timestamp: String?
        let requestId: String?
        let sessionId: String?
        let cwd: String?
        let message: Message?

        struct Message: Decodable {
            let id: String?
            let model: String?
            let usage: Usage?
        }

        struct Usage: Decodable {
            let input_tokens: Int?
            let output_tokens: Int?
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
        }
    }

    private let decoder = JSONDecoder()

    private func parse(file url: URL, from offset: Int) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        if offset > 0 { try? handle.seek(toOffset: UInt64(offset)) }
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }

        let quickFilter = Data("\"usage\"".utf8)
        var start = data.startIndex
        while start < data.endIndex {
            let end = data[start...].firstIndex(of: 0x0A) ?? data.endIndex
            defer { start = end < data.endIndex ? data.index(after: end) : data.endIndex }
            let line = data[start..<end]
            guard line.count > 2, line.range(of: quickFilter) != nil else { continue }
            ingest(line: line, projectDir: url.deletingLastPathComponent().lastPathComponent)
        }
    }

    private func ingest(line: Data, projectDir: String) {
        guard let entry = try? decoder.decode(LogLine.self, from: line),
              entry.type == "assistant",
              let message = entry.message,
              let usage = message.usage,
              let model = message.model,
              model != "<synthetic>",
              let timestamp = entry.timestamp,
              let date = Self.parseISO(timestamp) else { return }

        let input = usage.input_tokens ?? 0
        let output = usage.output_tokens ?? 0
        let cacheRead = usage.cache_read_input_tokens ?? 0
        let cacheWrite = usage.cache_creation_input_tokens ?? 0
        guard input + output + cacheRead + cacheWrite > 0 else { return }

        if let mid = message.id, let rid = entry.requestId {
            let key = mid + "|" + rid
            guard seen.insert(key).inserted else { return }
        }

        let day = Self.dayFormatter.string(from: date)
        let project = Self.projectName(fromCwd: entry.cwd, fallbackDir: projectDir)
        let cost = pricing.cost(model: model, input: input, output: output,
                                cacheRead: cacheRead, cacheWrite: cacheWrite)
        buckets[BucketKey(day: day, model: model, project: project), default: UsageBucket()]
            .add(input: input, output: output, cacheRead: cacheRead, cacheWrite: cacheWrite, cost: cost)
        if let session = entry.sessionId {
            sessionsByDay[day, default: []].insert(session)
        }
    }

    private static func projectName(fromCwd cwd: String?, fallbackDir: String) -> String {
        if let cwd, !cwd.isEmpty {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            if cwd == home { return "~" }
            let name = (cwd as NSString).lastPathComponent
            return name.isEmpty ? cwd : name
        }
        return fallbackDir
    }

    // MARK: - Dates

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseISO(_ s: String) -> Date? {
        isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
