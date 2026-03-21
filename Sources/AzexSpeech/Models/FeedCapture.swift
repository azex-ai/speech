import Foundation

struct FeedCapture: Codable, Identifiable {
    var id: String = UUID().uuidString
    var timestamp: Date
    var sourceApp: String
    var text: String
    var hotwords: [String]

    enum CodingKeys: String, CodingKey {
        case id, timestamp, text, hotwords
        case sourceApp = "source_app"
    }
}

struct FeedStore: Codable {
    var captures: [FeedCapture]
}
