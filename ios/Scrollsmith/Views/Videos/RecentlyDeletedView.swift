import SwiftUI

/// View showing soft-deleted videos with 30-day retention.
/// Users can restore videos or permanently delete them.
struct RecentlyDeletedView: View {
    // MARK: - State

    @State private var deletedVideos: [VideoDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var videoToDelete: VideoDTO?

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error Loading Videos", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task {
                            await loadRecentlyDeleted()
                        }
                    }
                }
            } else if deletedVideos.isEmpty {
                ContentUnavailableView {
                    Label("No Deleted Videos", systemImage: "trash.slash")
                } description: {
                    Text("Videos you delete will stay here for 30 days before being permanently removed.")
                }
            } else {
                List {
                    ForEach(deletedVideos) { video in
                        VideoRowWithDays(video: video)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    Task {
                                        await restore(video)
                                    }
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading) {
                                Button(role: .destructive) {
                                    videoToDelete = video
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete Now", systemImage: "trash.fill")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Recently Deleted")
        .task {
            await loadRecentlyDeleted()
        }
        .alert("Permanently Delete?", isPresented: $showDeleteConfirmation, presenting: videoToDelete) { video in
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                Task {
                    await deletePermanently(video)
                }
            }
        } message: { _ in
            Text("This video will be permanently deleted and cannot be restored. This action cannot be undone.")
        }
    }

    // MARK: - Methods

    @MainActor
    func loadRecentlyDeleted() async {
        isLoading = true
        errorMessage = nil

        do {
            deletedVideos = try await APIClient.shared.getDeletedVideos()
        } catch {
            errorMessage = "Failed to load deleted videos: \(error.localizedDescription)"
            print("❌ RecentlyDeletedView: Failed to load - \(error)")
        }

        isLoading = false
    }

    @MainActor
    func restore(_ video: VideoDTO) async {
        do {
            // Trigger haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            _ = try await APIClient.shared.restoreVideo(id: video.id)

            // Remove from list
            deletedVideos.removeAll { $0.id == video.id }

            print("✅ RecentlyDeletedView: Restored video \(video.id)")
        } catch {
            errorMessage = "Failed to restore video: \(error.localizedDescription)"
            print("❌ RecentlyDeletedView: Failed to restore - \(error)")
        }
    }

    @MainActor
    func deletePermanently(_ video: VideoDTO) async {
        do {
            // Trigger haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)

            try await APIClient.shared.permanentlyDeleteVideo(id: video.id)

            // Remove from list
            deletedVideos.removeAll { $0.id == video.id }

            print("✅ RecentlyDeletedView: Permanently deleted video \(video.id)")
        } catch {
            errorMessage = "Failed to delete video: \(error.localizedDescription)"
            print("❌ RecentlyDeletedView: Failed to permanently delete - \(error)")
        }
    }
}

// MARK: - Video Row with Days Remaining

private struct VideoRowWithDays: View {
    let video: VideoDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VideoFeedRow(video: video)

            if let daysRemaining = video.daysUntilPermanentDeletion {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(daysRemainingText(daysRemaining))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func daysRemainingText(_ days: Int) -> String {
        if days == 0 {
            return "Deleting soon"
        } else if days == 1 {
            return "1 day remaining"
        } else {
            return "\(days) days remaining"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecentlyDeletedView()
    }
}
