import Foundation

struct UsageStats: Codable {
    var totalCharacters: Int = 0
    var totalSessions: Int = 0
    var totalRecordingMs: Int = 0  // actual time spent recording (ms)
    var firstUseDate: String?

    /// Time saved = (typing time) - (recording time)
    /// Avg Chinese typing: ~40 chars/min (decent typist, not blazing fast)
    /// Only count positive savings
    var timeSavedMinutes: Double {
        let typingTimeMin = Double(totalCharacters) / 40.0
        let recordingTimeMin = Double(totalRecordingMs) / 60000.0
        return max(typingTimeMin - recordingTimeMin, 0)
    }

    enum CodingKeys: String, CodingKey {
        case totalCharacters = "total_characters"
        case totalSessions = "total_sessions"
        case totalRecordingMs = "total_recording_ms"
        case firstUseDate = "first_use_date"
    }
}
