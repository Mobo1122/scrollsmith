import Foundation

/// Backend response for user's video usage status.
///
/// Returned from GET /api/v1/subscriptions/usage
/// Used to display usage indicator and enforce free tier limits.
struct UsageResponse: Codable {
    let videosUsed: Int
    let videosLimit: Int  // -1 for unlimited (Pro tier)
    let canCreateVideo: Bool
    let resetDate: String  // ISO8601 date string
    let isPro: Bool

    enum CodingKeys: String, CodingKey {
        case videosUsed = "videos_used"
        case videosLimit = "videos_limit"
        case canCreateVideo = "can_create_video"
        case resetDate = "reset_date"
        case isPro = "is_pro"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Make fields optional with sensible defaults for Pro users
        videosUsed = try container.decodeIfPresent(Int.self, forKey: .videosUsed) ?? 0
        videosLimit = try container.decodeIfPresent(Int.self, forKey: .videosLimit) ?? -1
        canCreateVideo = try container.decodeIfPresent(Bool.self, forKey: .canCreateVideo) ?? true
        resetDate = try container.decodeIfPresent(String.self, forKey: .resetDate) ?? ISO8601DateFormatter().string(from: Date())
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
    }
}
