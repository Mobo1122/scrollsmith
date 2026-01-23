import AVFoundation
import UIKit

/// Service for generating video thumbnails using AVFoundation.
///
/// Uses AVAssetImageGenerator to extract a frame from the video.
/// Thumbnails are generated asynchronously to avoid blocking the main thread.
actor ThumbnailService {

    static let shared = ThumbnailService()

    private init() {}

    /// Generates a thumbnail image from a video URL.
    ///
    /// - Parameters:
    ///   - url: The local video file URL.
    ///   - time: The time in seconds to capture the frame (default: 1 second).
    ///   - maxSize: Maximum dimension for the thumbnail (default: 400).
    /// - Returns: A UIImage thumbnail.
    func generateThumbnail(
        from url: URL,
        at time: Double = 1.0,
        maxSize: CGFloat = 400
    ) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)

        // Correct orientation for videos shot in portrait
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxSize, height: maxSize)

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)

        // iOS 16+ async API
        let (cgImage, _) = try await generator.image(at: cmTime)
        return UIImage(cgImage: cgImage)
    }

    /// Gets the duration of a video in seconds.
    ///
    /// - Parameter url: The local video file URL.
    /// - Returns: Duration in seconds.
    func getVideoDuration(from url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    /// Formats a duration in seconds to a display string.
    ///
    /// - Parameter seconds: Duration in seconds.
    /// - Returns: Formatted string like "1:23" or "1:05:23".
    static func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
