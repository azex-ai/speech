import Foundation

struct OnboardingState: Codable {
    var completed: Bool = false
    var domain: String = "both"  // "ai", "crypto", "both"
    var completedAt: String?

    enum CodingKeys: String, CodingKey {
        case completed, domain
        case completedAt = "completed_at"
    }
}
