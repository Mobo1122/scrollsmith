import Foundation

/// Represents the source platform of a video.
enum VideoPlatform: String, Codable {
    case tiktok
    case instagram
    case youtube
    case cameraRoll
    case unknown

    /// SF Symbol name for the platform icon.
    var iconName: String {
        switch self {
        case .tiktok:
            return "music.note"  // TikTok-like icon
        case .instagram:
            return "camera"
        case .youtube:
            return "play.rectangle.fill"
        case .cameraRoll:
            return "photo.on.rectangle"
        case .unknown:
            return "link"
        }
    }

    /// Display name for the platform.
    var displayName: String {
        switch self {
        case .tiktok:
            return "TikTok"
        case .instagram:
            return "Instagram"
        case .youtube:
            return "YouTube"
        case .cameraRoll:
            return "Camera Roll"
        case .unknown:
            return "Unknown"
        }
    }
}

/// Represents a video source, either a URL or local file.
enum VideoSource {
    case url(String, VideoPlatform)
    case localFile(URL)

    var platform: VideoPlatform {
        switch self {
        case .url(_, let platform):
            return platform
        case .localFile:
            return .cameraRoll
        }
    }

    var urlString: String? {
        switch self {
        case .url(let string, _):
            return string
        case .localFile:
            return nil
        }
    }

    var localURL: URL? {
        switch self {
        case .url:
            return nil
        case .localFile(let url):
            return url
        }
    }
}
