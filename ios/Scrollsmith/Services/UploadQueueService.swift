import Foundation
import SwiftData

/// Service for processing pending video uploads.
///
/// Monitors the PendingUpload queue and processes items when the app is active.
/// Uses TranscriptionOrchestrator to route videos through the appropriate
/// transcription pipeline.
@MainActor
class UploadQueueService: ObservableObject {

    static let shared = UploadQueueService()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var currentItem: PendingUpload?

    /// The transcription orchestrator for the current item.
    let orchestrator = TranscriptionOrchestrator.shared

    private var modelContext: ModelContext?

    private init() {}

    /// Initializes the service with a model context.
    func configure(with context: ModelContext) {
        self.modelContext = context
        Task {
            await refreshPendingCount()
        }
    }

    /// Refreshes the count of pending uploads.
    func refreshPendingCount() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<PendingUpload>(
            predicate: #Predicate { $0.status == "pending" || $0.status == "failed" }
        )

        do {
            let pending = try context.fetch(descriptor)
            // Only count items that can still be processed
            pendingCount = pending.filter { $0.retryCount < 3 }.count
        } catch {
            print("Failed to fetch pending uploads: \(error)")
            pendingCount = 0
        }
    }

    /// Processes all pending uploads.
    ///
    /// Routes each upload through the TranscriptionOrchestrator based on its platform.
    func processQueue() async {
        guard let context = modelContext else { return }
        guard !isProcessing else { return }

        isProcessing = true

        // Fetch pending items (including failed items that can be retried)
        let descriptor = FetchDescriptor<PendingUpload>(
            predicate: #Predicate { $0.status == "pending" },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let pending = try context.fetch(descriptor)

            for upload in pending {
                // Skip if too many retries
                if upload.retryCount >= 3 {
                    continue
                }

                currentItem = upload

                // Process through orchestrator
                await orchestrator.process(upload, context: context)

                // Reset orchestrator for next item
                orchestrator.reset()

                await refreshPendingCount()
            }
        } catch {
            print("Failed to process queue: \(error)")
        }

        currentItem = nil
        isProcessing = false
        await refreshPendingCount()
    }

    /// Cleans up completed uploads older than the specified age.
    func cleanupCompleted(olderThan age: TimeInterval = 86400) async {
        guard let context = modelContext else { return }

        let cutoff = Date().addingTimeInterval(-age)

        let descriptor = FetchDescriptor<PendingUpload>(
            predicate: #Predicate {
                $0.status == "completed" && $0.processedAt != nil && $0.processedAt! < cutoff
            }
        )

        do {
            let completed = try context.fetch(descriptor)
            for item in completed {
                context.delete(item)
            }
            try context.save()
        } catch {
            print("Failed to cleanup completed uploads: \(error)")
        }
    }

    /// Retries a failed upload.
    func retry(_ upload: PendingUpload) async {
        guard let context = modelContext else { return }
        guard upload.canRetry else { return }

        upload.uploadStatus = .pending
        upload.processedAt = nil
        upload.errorMessage = nil

        do {
            try context.save()
            await refreshPendingCount()

            // Process immediately
            await processQueue()
        } catch {
            print("Failed to retry upload: \(error)")
        }
    }

    /// Deletes a pending upload.
    func delete(_ upload: PendingUpload) async {
        guard let context = modelContext else { return }

        context.delete(upload)

        do {
            try context.save()
            await refreshPendingCount()
        } catch {
            print("Failed to delete upload: \(error)")
        }
    }
}
