import SwiftUI

/// A sheet view for confirming video selection before processing.
///
/// Displays the video thumbnail, metadata, and confirm/cancel buttons.
/// Used after selecting a video from camera roll or capturing a URL.
struct VideoConfirmationSheet: View {
    let videoURL: URL
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var thumbnail: UIImage?
    @State private var duration: String?
    @State private var fileSize: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                VideoPreviewCard(
                    thumbnail: thumbnail,
                    duration: duration,
                    fileSize: fileSize,
                    isLoading: isLoading
                )

                Text("Ready to process this video?")
                    .font(Typography.headline)

                Text("The video will be transcribed and summarized.")
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.Text.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: Spacing.sm) {
                    Button(action: onConfirm) {
                        Text("Process Video")
                            .font(Typography.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                    }

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(Typography.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(Theme.Semantic.error)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Confirm Video")
                        .font(Typography.title3)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .task {
            await loadVideoMetadata()
        }
    }

    private func loadVideoMetadata() async {
        do {
            // Generate thumbnail
            let image = try await ThumbnailService.shared.generateThumbnail(from: videoURL)

            // Get duration
            let durationSeconds = try await ThumbnailService.shared.getVideoDuration(from: videoURL)
            let formattedDuration = ThumbnailService.formatDuration(durationSeconds)

            // Get file size
            let bytes = VideoFileManager.fileSize(for: videoURL)
            let formattedSize = bytes.map { VideoFileManager.formatFileSize($0) }

            await MainActor.run {
                self.thumbnail = image
                self.duration = formattedDuration
                self.fileSize = formattedSize
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

#Preview {
    VideoConfirmationSheet(
        videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
        onConfirm: {},
        onCancel: {}
    )
}
