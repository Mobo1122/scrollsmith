import AVFoundation
import Foundation

// MARK: - v2 TODO
// This service was created for on-device transcription (Phase 4 original design).
// For v1, we upload the full video to the backend for server-side transcription.
//
// TODO v2: Use this for on-device WhisperKit transcription of TikTok/IG URLs.
// The backend can use ffmpeg for audio extraction from uploaded videos.

/// Extracts audio tracks from video files using AVFoundation.
///
/// **Used in v1** for extracting audio before server-side upload (optional).
/// **Used in v2** for on-device WhisperKit/Speech transcription.
///
/// Exports the audio track to M4A format which is compatible with
/// WhisperKit, Speech Framework, and server-side Whisper API.
actor AudioExtractor {

    static let shared = AudioExtractor()

    /// Temp directory for extracted audio files.
    private static let audioTempDir: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio_extraction", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    /// Extracts audio from a video file.
    ///
    /// - Parameter videoURL: Local video file URL.
    /// - Returns: URL to the extracted M4A audio file.
    /// - Throws: `AudioExtractionError` if extraction fails.
    func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        // Check for audio track
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioExtractionError.noAudioTrack
        }

        // Create output URL
        let outputURL = Self.audioTempDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        // Configure export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExtractionError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Export asynchronously
        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw AudioExtractionError.exportFailed(exportSession.error)
        case .cancelled:
            throw AudioExtractionError.exportCancelled
        default:
            throw AudioExtractionError.unknownError
        }
    }

    /// Cleans up an extracted audio file.
    ///
    /// - Parameter audioURL: URL of the audio file to delete.
    func cleanup(audioURL: URL) {
        try? FileManager.default.removeItem(at: audioURL)
    }

    /// Cleans up all extracted audio files.
    func cleanupAll() {
        try? FileManager.default.removeItem(at: Self.audioTempDir)
        try? FileManager.default.createDirectory(at: Self.audioTempDir, withIntermediateDirectories: true)
    }

    /// Gets duration of an audio file in seconds.
    ///
    /// - Parameter audioURL: Local audio file URL.
    /// - Returns: Duration in seconds.
    func getDuration(from audioURL: URL) async throws -> Double {
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}

/// Errors that can occur during audio extraction.
enum AudioExtractionError: LocalizedError {
    case noAudioTrack
    case exportSessionFailed
    case exportFailed(Error?)
    case exportCancelled
    case unknownError

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "Video has no audio track"
        case .exportSessionFailed:
            return "Could not create audio export session"
        case .exportFailed(let error):
            return "Audio export failed: \(error?.localizedDescription ?? "unknown error")"
        case .exportCancelled:
            return "Audio export was cancelled"
        case .unknownError:
            return "Unknown audio extraction error"
        }
    }
}
