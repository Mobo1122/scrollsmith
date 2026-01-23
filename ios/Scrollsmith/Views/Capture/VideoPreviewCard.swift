import SwiftUI

/// A card view that displays a video thumbnail with metadata.
///
/// Shows the thumbnail image, duration, and file size.
/// Used in the confirmation sheet before upload.
struct VideoPreviewCard: View {
    let thumbnail: UIImage?
    let duration: String?
    let fileSize: String?
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Thumbnail
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                } else if isLoading {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay {
                            ProgressView()
                        }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                }

                // Duration badge
                if let duration = duration {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(duration)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                                .padding(8)
                        }
                    }
                }
            }
            .frame(height: 200)

            // Metadata
            if let fileSize = fileSize {
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                    Text(fileSize)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}

#Preview("With Thumbnail") {
    VideoPreviewCard(
        thumbnail: UIImage(systemName: "video.fill"),
        duration: "1:23",
        fileSize: "12.5 MB",
        isLoading: false
    )
    .padding()
}

#Preview("Loading") {
    VideoPreviewCard(
        thumbnail: nil,
        duration: nil,
        fileSize: nil,
        isLoading: true
    )
    .padding()
}
