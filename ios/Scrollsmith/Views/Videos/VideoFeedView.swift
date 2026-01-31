import SwiftUI
import Kingfisher

/// Feed view displaying videos in a list with thumbnail and description.
///
/// Replaces VideoGridView for the main Library view. Shows videos in a
/// vertically scrolling list with thumbnail on left, metadata on right.
struct VideoFeedView: View {
    // MARK: - Properties

    let playbookId: UUID?
    let showUncategorized: Bool

    @State private var videos: [VideoDTO] = []
    @State private var isLoading = false
    @State private var error: AppError?

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                // Skeleton loading state
                List(0..<6, id: \.self) { _ in
                    VideoFeedSkeletonRow()
                }
                .listStyle(.plain)
                .redacted(reason: .placeholder)
            } else if videos.isEmpty {
                ContentUnavailableView(
                    "No Videos",
                    systemImage: "video.slash",
                    description: Text(showUncategorized ? "All videos are organized" : "Add videos to get started")
                )
            } else {
                feedList
            }
        }
        .task {
            await loadVideos()
        }
        .refreshable {
            await loadVideos()
        }
        .errorAlert(
            $error,
            retryAction: {
                Task {
                    await loadVideos()
                }
            }
        )
    }

    // MARK: - Feed List

    private var feedList: some View {
        List {
            ForEach(videos) { video in
                NavigationLink(value: video) {
                    VideoFeedRow(video: video)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadVideos() async {
        isLoading = true
        error = nil
        do {
            videos = try await APIClient.shared.getVideos(
                playbookId: playbookId,
                uncategorized: showUncategorized
            )
        } catch {
            self.error = AppError.from(error)
            CrashReportingService.shared.captureError(error, context: [
                "action": "loadVideos",
                "playbookId": playbookId?.uuidString ?? "nil",
                "uncategorized": showUncategorized
            ])
        }
        isLoading = false
    }
}

// MARK: - VideoFeedRow

/// A single video row in the feed with thumbnail and metadata.
struct VideoFeedRow: View {
    let video: VideoDTO

    /// Derive a display title from available data
    private var displayTitle: String {
        // Try to extract meaningful title
        if let tags = video.tags, !tags.isEmpty {
            return tags.first ?? "Video"
        }

        if let sourceUrl = video.sourceUrl {
            if sourceUrl.contains("youtube") {
                return "YouTube Video"
            } else if sourceUrl.contains("camera_roll") {
                return "Camera Roll Video"
            }
        }

        return "Video"
    }

    /// Derive description from summary bullets
    private var displayDescription: String {
        if let bullets = video.summaryBullets, !bullets.isEmpty {
            // Return first line as preview
            let firstLine = bullets.components(separatedBy: "\n").first ?? bullets
            return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Processing..."
    }

    /// Icon based on source platform
    private var platformIcon: String {
        guard let sourceUrl = video.sourceUrl else { return "play.circle.fill" }

        if sourceUrl.contains("youtube") {
            return "play.rectangle.fill"
        } else if sourceUrl.contains("camera_roll") {
            return "photo.on.rectangle"
        }
        return "play.circle.fill"
    }

    /// Format date for display
    private var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: video.createdAt, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail with Kingfisher caching
            KFImage(URL(string: video.thumbnailUrl ?? ""))
                .placeholder {
                    // Fallback while loading or if no URL
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: platformIcon)
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                }
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: 100, height: 60)
                .cornerRadius(8)
                .clipped()
                .cancelOnDisappear(true)  // Critical: cancel download when scrolled off-screen

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(Typography.headline)
                    .lineLimit(1)

                Text(displayDescription)
                    .font(Typography.footnote)
                    .foregroundStyle(Theme.Text.secondary)
                    .lineLimit(2)

                if !dateString.isEmpty {
                    Text(dateString)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Skeleton Loading Row

/// Skeleton placeholder row for loading state
private struct VideoFeedSkeletonRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 100, height: 60)

            // Content placeholders
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 14)
                    .frame(maxWidth: 200)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                    .frame(maxWidth: 80)
            }

            Spacer()
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

// MARK: - Default Initializer

extension VideoFeedView {
    /// Creates a VideoFeedView for "All Videos" view (Library).
    init() {
        self.init(playbookId: nil, showUncategorized: false)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VideoFeedView()
            .navigationTitle("Library")
    }
}
