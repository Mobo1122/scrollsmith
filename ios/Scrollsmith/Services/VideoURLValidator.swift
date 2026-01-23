import Foundation

/// Validates and identifies video URLs from supported platforms.
///
/// Supports TikTok, Instagram, and YouTube URL formats.
/// Uses regex patterns to validate and extract video IDs.
enum VideoURLValidator {

    // MARK: - Regex Patterns

    /// TikTok URL patterns
    /// Matches: tiktok.com/@user/video/123, vm.tiktok.com/abc, m.tiktok.com/v/123
    private static let tiktokPattern = #"(?:https?://)?(?:(?:www|m|vm)\.)?tiktok\.com/(?:@[\w.-]+/video/\d+|v/\d+|[\w]+)"#

    /// Instagram URL patterns
    /// Matches: instagram.com/p/ABC123, instagram.com/reel/ABC123, instagram.com/tv/ABC123
    private static let instagramPattern = #"(?:https?://)?(?:www\.)?instagram\.com/(?:p|reel|tv)/[\w-]+/?"#

    /// YouTube URL patterns
    /// Matches: youtube.com/watch?v=, youtu.be/, youtube.com/shorts/
    private static let youtubePattern = #"(?:https?://)?(?:(?:www|m)\.)?(?:youtube\.com/(?:watch\?v=|shorts/)|youtu\.be/)[\w-]+"#

    // MARK: - Validation

    /// Validates a URL string and returns the detected platform.
    ///
    /// - Parameter urlString: The URL string to validate.
    /// - Returns: A tuple with validation result and detected platform.
    static func validate(_ urlString: String) -> (isValid: Bool, platform: VideoPlatform) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return (false, .unknown)
        }

        if matches(trimmed, pattern: tiktokPattern) {
            return (true, .tiktok)
        }

        if matches(trimmed, pattern: instagramPattern) {
            return (true, .instagram)
        }

        if matches(trimmed, pattern: youtubePattern) {
            return (true, .youtube)
        }

        return (false, .unknown)
    }

    /// Checks if a string matches a regex pattern.
    private static func matches(_ string: String, pattern: String) -> Bool {
        string.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Video ID Extraction

    /// Extracts the video ID from a validated URL.
    ///
    /// - Parameters:
    ///   - urlString: The URL string.
    ///   - platform: The detected platform.
    /// - Returns: The extracted video ID, or nil if extraction fails.
    static func extractVideoId(_ urlString: String, platform: VideoPlatform) -> String? {
        guard let url = URL(string: urlString) else { return nil }

        switch platform {
        case .youtube:
            return extractYouTubeId(from: url, urlString: urlString)
        case .tiktok:
            return extractTikTokId(from: url)
        case .instagram:
            return extractInstagramId(from: url)
        default:
            return nil
        }
    }

    private static func extractYouTubeId(from url: URL, urlString: String) -> String? {
        // Try query parameter first (youtube.com/watch?v=ID)
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoId
        }

        // Try path component (youtu.be/ID or shorts/ID)
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        if let last = pathComponents.last, !last.isEmpty {
            return last
        }

        return nil
    }

    private static func extractTikTokId(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }

        // Look for /video/ID pattern
        if let videoIndex = components.firstIndex(of: "video"),
           videoIndex + 1 < components.count {
            return components[videoIndex + 1]
        }

        // vm.tiktok.com short links - the ID is the path
        if url.host?.contains("vm.tiktok") == true,
           let shortCode = components.first {
            return shortCode
        }

        return nil
    }

    private static func extractInstagramId(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }

        // Look for /p/ID, /reel/ID, or /tv/ID pattern
        if components.contains(where: { ["p", "reel", "tv"].contains($0) }),
           let postId = components.last {
            return postId
        }

        return nil
    }

    // MARK: - URL Normalization

    /// Ensures a URL string has a scheme (adds https:// if missing).
    ///
    /// - Parameter urlString: The URL string.
    /// - Returns: The normalized URL string with scheme.
    static func normalize(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }

        return "https://" + trimmed
    }
}
