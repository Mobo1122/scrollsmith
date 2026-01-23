import SwiftUI
import AVKit
import Photos

/// Inline video player for camera roll content.
///
/// Per CONTEXT.md: Inline player by default with thumbnail + play icon + duration.
/// Basic controls only (play/pause, scrubber, mute) - preview feel.
/// No autoplay - user explicitly starts playback.
struct InlineVideoPlayerView: View {
    let localIdentifier: String

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: String?
    @State private var thumbnailImage: UIImage?
    @State private var duration: TimeInterval?
    @State private var showPlayer = false

    var body: some View {
        Group {
            if showPlayer, let player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isLoading {
                loadingView
            } else if let error {
                errorView(message: error)
            } else {
                thumbnailView
            }
        }
        .task {
            await loadVideoMetadata()
        }
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: - Thumbnail View

    private var thumbnailView: some View {
        ZStack {
            if let thumbnail = thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .aspectRatio(16/9, contentMode: .fit)
            }

            // Play button overlay
            Button {
                Task {
                    await loadFullVideo()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)

                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(.primary)
                }
            }

            // Duration badge
            if let duration {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(12)
                    }
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                ProgressView()
            }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Video Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
        .frame(height: 200)
    }

    // MARK: - Video Metadata Loading

    private func loadVideoMetadata() async {
        // Parse local identifier - may have "ph://" prefix
        let identifier = localIdentifier.replacingOccurrences(of: "ph://", with: "")

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )

        guard let asset = fetchResult.firstObject else {
            await MainActor.run {
                error = "Video not found in library. It may have been deleted."
                isLoading = false
            }
            return
        }

        guard asset.mediaType == .video else {
            await MainActor.run {
                error = "This asset is not a video."
                isLoading = false
            }
            return
        }

        // Store duration
        await MainActor.run {
            self.duration = asset.duration
        }

        // Request thumbnail
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 640, height: 360)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: imageOptions
        ) { image, info in
            DispatchQueue.main.async {
                if let image {
                    self.thumbnailImage = image
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - Full Video Loading

    private func loadFullVideo() async {
        // Parse local identifier - may have "ph://" prefix
        let identifier = localIdentifier.replacingOccurrences(of: "ph://", with: "")

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )

        guard let asset = fetchResult.firstObject else {
            await MainActor.run {
                error = "Video not found in library. It may have been deleted."
            }
            return
        }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true  // Allow iCloud download

        // Request video with callback-based API
        PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: options
        ) { avAsset, _, info in
            DispatchQueue.main.async {
                if let urlAsset = avAsset as? AVURLAsset {
                    self.player = AVPlayer(url: urlAsset.url)
                    self.showPlayer = true
                    // No autoplay per CONTEXT.md - user must tap play in VideoPlayer
                } else if let avAsset {
                    // Handle non-URL assets (rare)
                    let playerItem = AVPlayerItem(asset: avAsset)
                    self.player = AVPlayer(playerItem: playerItem)
                    self.showPlayer = true
                } else {
                    // Check for error in info dictionary
                    if let nsError = info?[PHImageErrorKey] as? NSError {
                        self.error = nsError.localizedDescription
                    } else {
                        self.error = "Could not load video"
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    InlineVideoPlayerView(localIdentifier: "test-identifier")
        .padding()
}
