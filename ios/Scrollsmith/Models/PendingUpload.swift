import Foundation
import SwiftData

/// Represents a video pending upload/processing.
///
/// Used to communicate between the Share Extension and the main app.
/// The Share Extension creates PendingUpload records, and the main app
/// processes them when it becomes active.
@Model
final class PendingUpload {
    @Attribute(.unique) var id: UUID
    var sourceURL: String
    var platform: String
    var createdAt: Date
    var processedAt: Date?
    var status: String

    // Transcription fields (Phase 4)
    var transcript: String?
    var errorMessage: String?
    var retryCount: Int
    var videoId: UUID?  // Backend video ID after successful save

    /// Status values for tracking upload progress.
    ///
    /// v1 uses server-side transcription, so some states are simplified.
    enum Status: String {
        case pending
        case downloading      // v1: Uploading file to backend (reused name for compatibility)
        case extractingAudio  // Extracting audio track before upload
        case loadingModel     // v2 TODO: Loading WhisperKit model (not used in v1)
        case transcribing     // Server-side transcription in progress
        case saving           // Saving to backend
        case completed
        case failed
    }

    init(
        id: UUID = UUID(),
        sourceURL: String,
        platform: String = "unknown",
        createdAt: Date = Date(),
        status: Status = .pending
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.platform = platform
        self.createdAt = createdAt
        self.status = status.rawValue
        self.retryCount = 0
    }

    /// Computed property for status enum.
    var uploadStatus: Status {
        get { Status(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    /// The detected video platform.
    var videoPlatform: VideoPlatform {
        VideoPlatform(rawValue: platform) ?? .unknown
    }

    /// Whether this upload can be retried.
    var canRetry: Bool {
        uploadStatus == .failed && retryCount < 3
    }

    /// User-friendly status description.
    var statusDescription: String {
        switch uploadStatus {
        case .pending: return "Waiting..."
        case .downloading: return "Uploading..."  // v1: uploading to backend
        case .extractingAudio: return "Preparing audio..."
        case .loadingModel: return "Loading..."  // v2 TODO: WhisperKit model loading
        case .transcribing: return "Transcribing..."
        case .saving: return "Saving..."
        case .completed: return "Done"
        case .failed: return errorMessage ?? "Failed"
        }
    }
}
