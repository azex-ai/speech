import Foundation

struct HistoryEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var timestamp: Date
    var original: String
    var corrected: String
    var learned: [[String]]  // pairs of [original, corrected]
    var durationMs: Int
    var charCount: Int

    enum CodingKeys: String, CodingKey {
        case id, timestamp, original, corrected, learned
        case durationMs = "duration_ms"
        case charCount = "char_count"
    }
}

struct DailyHistory: Codable {
    var entries: [HistoryEntry]
}
