import Foundation
import SwiftData

// MARK: - v1 Architecture
// Transcription is server-side only in v1 (macOS 13 dev environment cannot build WhisperKit).
//
// v1 Paths:
// - Camera Roll: Upload video → Backend transcribes via Whisper/AssemblyAI
// - YouTube: Backend fetches captions via youtube-transcript-api
// - TikTok/IG: NOT SUPPORTED in v1 (users download to camera roll)
//
// TODO v2: Add on-device transcription for TikTok/IG URLs using WhisperKit

/// Orchestrates transcription based on video source.
///
/// **v1 Implementation (server-side only):**
/// - Camera Roll: Upload video to backend for transcription
/// - YouTube: Backend fetches captions via youtube-transcript-api
/// - TikTok/Instagram: **DEFERRED TO v2** (users download to camera roll)
///
/// **v2 (future):**
/// - TikTok/Instagram: Download media, transcribe on-device via WhisperKit
@MainActor
class TranscriptionOrchestrator: ObservableObject {

    static let shared = TranscriptionOrchestrator()

    /// Current transcription state.
    @Published private(set) var state: TranscriptionState = .idle

    /// Progress of current operation (0.0 to 1.0).
    @Published private(set) var progress: Double = 0

    enum TranscriptionState: Equatable {
        case idle
        case uploading        // v1: uploading file to backend
        case transcribing     // Backend transcribing
        case saving           // Saving result
        case completed(transcript: String)
        case failed(message: String)
        case unavailable(message: String)  // e.g., YouTube without captions

        static func == (lhs: TranscriptionState, rhs: TranscriptionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.uploading, .uploading),
                 (.transcribing, .transcribing), (.saving, .saving):
                return true
            case (.completed(let a), .completed(let b)):
                return a == b
            case (.failed(let a), .failed(let b)):
                return a == b
            case (.unavailable(let a), .unavailable(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private init() {}

    /// Processes a pending upload through the transcription pipeline.
    ///
    /// Updates the upload's status as it progresses through stages.
    func process(_ upload: PendingUpload, context: ModelContext) async {
        let platform = upload.videoPlatform

        do {
            let transcript: String

            switch platform {
            case .youtube:
                transcript = try await processYouTube(url: upload.sourceURL, upload: upload, context: context)

            case .tiktok, .instagram:
                // v1: TikTok/IG URL not supported - show error
                // TODO v2: Enable on-device download + WhisperKit transcription
                throw TranscriptionError.platformNotSupportedInV1(platform.displayName)

            case .cameraRoll:
                transcript = try await processCameraRoll(localPath: upload.sourceURL, upload: upload, context: context)

            case .unknown:
                throw TranscriptionError.unknownPlatform
            }

            // Update upload record with success
            upload.transcript = transcript
            upload.uploadStatus = .completed
            upload.processedAt = Date()
            try context.save()

            // Trigger summarization if we have a video ID
            if let videoId = upload.videoId {
                do {
                    _ = try await APIClient.shared.summarizeVideo(videoId: videoId, format: "bullets")
                } catch {
                    // Summarization failure is non-fatal - video is still saved
                    print("Summarization failed (non-fatal): \(error)")
                }
            }

            state = .completed(transcript: transcript)
            progress = 1.0

        } catch TranscriptionError.noCaptionsAvailable {
            // Special handling for YouTube without captions
            upload.uploadStatus = .failed
            upload.errorMessage = "Transcript unavailable - this video has no captions"
            upload.retryCount = 3  // Don't allow retry
            try? context.save()

            state = .unavailable(message: "This YouTube video has no captions available")

        } catch {
            // Update upload record with failure
            upload.uploadStatus = .failed
            upload.errorMessage = error.localizedDescription
            upload.retryCount += 1
            try? context.save()

            state = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - YouTube Path (v1: captions only, no fallback)

    private func processYouTube(url: String, upload: PendingUpload, context: ModelContext) async throws -> String {
        updateStatus(.transcribing, upload: upload, context: context)
        progress = 0.3

        let captionsResponse = try await APIClient.shared.getYouTubeCaptions(url: url)

        if captionsResponse.success, let transcript = captionsResponse.transcript {
            // Got captions from API - video already created on backend
            if let videoId = captionsResponse.videoId {
                upload.videoId = videoId
            }
            progress = 1.0
            return transcript
        }

        // v1: No fallback - just report unavailable
        // TODO v2: Fall back to download + on-device WhisperKit transcription
        if captionsResponse.errorType == "no_captions" {
            throw TranscriptionError.noCaptionsAvailable
        }

        throw TranscriptionError.transcriptionFailed(
            NSError(domain: "YouTube", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: captionsResponse.error ?? "Unknown error"])
        )
    }

    // MARK: - Camera Roll Path (v1: upload to backend)

    private func processCameraRoll(localPath: String, upload: PendingUpload, context: ModelContext) async throws -> String {
        guard let videoURL = URL(string: localPath) else {
            throw TranscriptionError.invalidURL
        }

        // Upload video to backend for transcription
        updateStatus(.uploading, upload: upload, context: context)
        progress = 0.1

        // Extract audio first (smaller file to upload)
        let audioURL = try await AudioExtractor.shared.extractAudio(from: videoURL)
        progress = 0.3

        defer {
            Task {
                await AudioExtractor.shared.cleanup(audioURL: audioURL)
            }
        }

        updateStatus(.transcribing, upload: upload, context: context)
        progress = 0.5

        // Upload audio and get transcript from backend
        let response = try await APIClient.shared.uploadAndTranscribe(
            audioURL: audioURL,
            platform: "camera_roll"
        ) { uploadProgress in
            Task { @MainActor in
                // Map upload progress to 0.3-0.7 range
                self.progress = 0.3 + (uploadProgress * 0.4)
            }
        }

        upload.videoId = response.id
        progress = 0.9

        guard let transcript = response.transcript, !transcript.isEmpty else {
            throw TranscriptionError.emptyTranscript
        }

        return transcript
    }

    // MARK: - Helpers

    private func updateStatus(_ newState: TranscriptionState, upload: PendingUpload, context: ModelContext) {
        state = newState

        // Map orchestrator state to upload status
        switch newState {
        case .uploading:
            upload.uploadStatus = .downloading  // Reuse downloading status for upload
        case .transcribing:
            upload.uploadStatus = .transcribing
        case .saving:
            upload.uploadStatus = .saving
        default:
            break
        }

        try? context.save()
    }

    /// Resets the orchestrator to idle state.
    func reset() {
        state = .idle
        progress = 0
    }
}

/// Errors that can occur during transcription orchestration.
enum TranscriptionError: LocalizedError {
    case unknownPlatform
    case invalidURL
    case platformNotSupportedInV1(String)
    case noCaptionsAvailable
    case emptyTranscript
    case transcriptionFailed(Error)
    case uploadFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unknownPlatform:
            return "Unknown video platform"
        case .invalidURL:
            return "Invalid video URL"
        case .platformNotSupportedInV1(let platform):
            return "\(platform) URL import coming soon! For now, download the video to your camera roll and upload from there."
        case .noCaptionsAvailable:
            return "Transcript unavailable - this video has no captions"
        case .emptyTranscript:
            return "No speech detected in video"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save video: \(error.localizedDescription)"
        }
    }
}
