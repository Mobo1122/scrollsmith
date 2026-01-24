import SwiftUI

/// Detail view for a Playbook showing its videos in a grid.
///
/// Features:
/// - Lazy grid of video thumbnails
/// - Pull to refresh
/// - Empty state when no videos
struct PlaybookDetailView: View {
    let playbook: PlaybookDTO

    @State private var videos: [VideoDTO] = []
    @State private var isLoading = false
    @State private var error: String?

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                ProgressView("Loading videos...")
            } else if let error = error, videos.isEmpty {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if videos.isEmpty {
                emptyState
            } else {
                videoGrid
            }
        }
        .navigationTitle(playbook.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadVideos()
        }
        .refreshable {
            await loadVideos()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView(
            "No Videos",
            systemImage: playbook.isSystem ? "star.slash" : "video.slash",
            description: Text(playbook.isSystem
                ? "Add videos to Favorites from the video picker"
                : "Add videos to this Playbook from the video picker")
        )
    }

    private var videoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(videos) { video in
                    NavigationLink {
                        SummaryDisplayView(video: video)
                    } label: {
                        VideoThumbnailCard(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    // MARK: - Data Loading

    private func loadVideos() async {
        isLoading = true
        error = nil

        do {
            videos = try await APIClient.shared.getVideos(playbookId: playbook.id)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - VideoThumbnailCard

/// A card displaying a video thumbnail with optional tags.
struct VideoThumbnailCard: View {
    let video: VideoDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.8))
                }

            // Tags preview
            if let tags = video.tags, !tags.isEmpty {
                Text(tags.prefix(2).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlaybookDetailView(playbook: PlaybookDTO(
            id: UUID(),
            name: "Cooking Tips",
            icon: "frying.pan",
            isSystem: false,
            videoCount: 5,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
