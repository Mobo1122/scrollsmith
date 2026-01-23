import UIKit
import Foundation

/// Handles deep-linking to source videos on various platforms.
///
/// YouTube: Opens with timestamp parameter (&t=N seconds)
/// TikTok/Instagram: Uses HTTPS URLs for universal link interception
/// Camera Roll: Returns nil - use InlineVideoPlayerView instead
struct DeepLinkService {

    enum Platform {
        case youtube(videoId: String, timestampSeconds: Int?)
        case tiktok(videoUrl: String)
        case instagram(postUrl: String)
        case cameraRoll(localIdentifier: String)
        case unknown(sourceUrl: String)

        /// Parses platform from source URL string.
        static func from(sourceUrl: String?) -> Platform? {
            guard let urlString = sourceUrl, !urlString.isEmpty else {
                return nil
            }

            if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
                // Extract video ID from YouTube URL
                if let videoId = extractYouTubeVideoId(from: urlString) {
                    return .youtube(videoId: videoId, timestampSeconds: nil)
                }
            }

            if urlString.contains("tiktok.com") {
                return .tiktok(videoUrl: urlString)
            }

            if urlString.contains("instagram.com") {
                return .instagram(postUrl: urlString)
            }

            // Camera roll uses local PHAsset identifiers (not URLs)
            if urlString.hasPrefix("ph://") || urlString.contains("asset") {
                return .cameraRoll(localIdentifier: urlString)
            }

            return .unknown(sourceUrl: urlString)
        }

        private static func extractYouTubeVideoId(from urlString: String) -> String? {
            // Handle youtube.com/watch?v=VIDEO_ID
            if let url = URL(string: urlString),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return videoId
            }

            // Handle youtu.be/VIDEO_ID
            if urlString.contains("youtu.be/") {
                let parts = urlString.components(separatedBy: "youtu.be/")
                if parts.count > 1 {
                    // Remove any query params
                    return parts[1].components(separatedBy: "?").first
                }
            }

            // Handle youtube.com/shorts/VIDEO_ID
            if urlString.contains("/shorts/") {
                let parts = urlString.components(separatedBy: "/shorts/")
                if parts.count > 1 {
                    // Remove any query params
                    return parts[1].components(separatedBy: "?").first
                }
            }

            return nil
        }
    }

    /// Opens the source URL for the given platform.
    ///
    /// - Parameters:
    ///   - platform: The platform enum with URL details
    ///   - timestampSeconds: Optional timestamp for YouTube videos
    /// - Returns: True if URL was opened, false if camera roll or unavailable
    @discardableResult
    func open(_ platform: Platform, timestampSeconds: Int? = nil) -> Bool {
        let url: URL?

        switch platform {
        case .youtube(let videoId, let storedTimestamp):
            // Use provided timestamp or stored timestamp
            let timestamp = timestampSeconds ?? storedTimestamp
            var urlString = "https://www.youtube.com/watch?v=\(videoId)"
            if let t = timestamp, t > 0 {
                urlString += "&t=\(t)"  // Seconds format per RESEARCH.md
            }
            url = URL(string: urlString)

        case .tiktok(let videoUrl):
            // TikTok: Use HTTPS URL, app intercepts via universal links
            url = URL(string: videoUrl)

        case .instagram(let postUrl):
            // Instagram: Use HTTPS URL, app intercepts via universal links
            url = URL(string: postUrl)

        case .cameraRoll:
            // Camera roll: Don't try to deep link - use InlineVideoPlayerView
            // Per RESEARCH.md pitfall: Photos app deep link to specific asset is unreliable
            return false

        case .unknown(let sourceUrl):
            url = URL(string: sourceUrl)
        }

        guard let openUrl = url else {
            return false
        }

        UIApplication.shared.open(openUrl, options: [:], completionHandler: nil)
        return true
    }

    /// Checks if the platform supports deep-linking.
    func canDeepLink(_ platform: Platform) -> Bool {
        switch platform {
        case .youtube, .tiktok, .instagram, .unknown:
            return true
        case .cameraRoll:
            return false
        }
    }

    /// Returns human-readable platform name for UI.
    func displayName(for platform: Platform) -> String {
        switch platform {
        case .youtube:
            return "YouTube"
        case .tiktok:
            return "TikTok"
        case .instagram:
            return "Instagram"
        case .cameraRoll:
            return "Camera Roll"
        case .unknown:
            return "Original"
        }
    }

    /// Returns SF Symbol name for platform icon.
    func iconName(for platform: Platform) -> String {
        switch platform {
        case .youtube:
            return "play.rectangle.fill"
        case .tiktok:
            return "music.note"
        case .instagram:
            return "camera.fill"
        case .cameraRoll:
            return "photo.on.rectangle"
        case .unknown:
            return "link"
        }
    }
}
