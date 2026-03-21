import Foundation

/// JSON vocabulary file structure
struct VocabFile: Codable {
    var domain: String
    var calibratedAt: String?
    var version: String?
    var corrections: [String: String]

    init(domain: String = "", corrections: [String: String] = [:]) {
        self.domain = domain
        self.corrections = corrections
    }

    enum CodingKeys: String, CodingKey {
        case domain
        case calibratedAt = "calibrated_at"
        case version
        case corrections
    }
}
