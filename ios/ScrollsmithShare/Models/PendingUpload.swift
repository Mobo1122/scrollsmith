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

    /// Status values for tracking upload progress.
    enum Status: String {
        case pending
        case processing
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
}
