import Foundation

@MainActor
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published var entries: [HistoryEntry] = []

    private let historyDir: URL
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("AzexSpeech", isDirectory: true)
            .appendingPathComponent("history", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.historyDir = dir
        entries = loadDate(Date())
    }

    func addEntry(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        saveToday()
    }

    func loadDate(_ date: Date) -> [HistoryEntry] {
        let filename = dateFormatter.string(from: date) + ".json"
        let url = historyDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let daily = try? Self.decoder.decode(DailyHistory.self, from: data) else {
            return []
        }
        return daily.entries.reversed()
    }

    func allDates() -> [String] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: historyDir,
                                                       includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { $0.deletingPathExtension().lastPathComponent }
            .sorted(by: >)
    }

    func deleteEntry(id: String) {
        entries.removeAll { $0.id == id }
        saveToday()
    }

    func clearToday() {
        entries.removeAll()
        saveToday()
    }

    // MARK: - Private

    private func saveToday() {
        let filename = dateFormatter.string(from: Date()) + ".json"
        let url = historyDir.appendingPathComponent(filename)
        let daily = DailyHistory(entries: entries)
        guard let data = try? Self.encoder.encode(daily) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
