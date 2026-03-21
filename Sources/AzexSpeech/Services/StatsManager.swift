import Foundation

@MainActor
final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published var stats: UsageStats = UsageStats()

    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("AzexSpeech", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("stats.json")
        load()
    }

    func recordSession(charCount: Int, durationMs: Int = 0) {
        stats.totalCharacters += charCount
        stats.totalSessions += 1
        stats.totalRecordingMs += durationMs
        if stats.firstUseDate == nil {
            stats.firstUseDate = ISO8601DateFormatter().string(from: Date())
        }
        save()
    }

    var todaySessionCount: Int {
        HistoryManager.shared.entries.count
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(UsageStats.self, from: data) else {
            return
        }
        stats = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(stats) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
