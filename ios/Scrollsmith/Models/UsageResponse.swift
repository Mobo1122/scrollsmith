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
}
