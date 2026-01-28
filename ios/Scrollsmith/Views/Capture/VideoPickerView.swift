import PhotosUI
import SwiftUI

/// A view that presents the PhotosPicker for video selection.
///
/// Uses SwiftUI's PhotosPicker with a `.videos` filter to only show
/// video content. The selected video is loaded as a MovieTransferable
/// and the URL is passed to the parent view via a binding.
struct VideoPickerView: View {
    @Binding var selectedVideoURL: URL?
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos,
            photoLibrary: .shared()
        ) {
            Label("Select from Camera Roll", systemImage: "photo.on.rectangle")
                .font(Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
        }
        .onChange(of: selectedItem) { _, newValue in
            guard let item = newValue else { return }
            loadVideo(from: item)
        }
    }

    private func loadVideo(from item: PhotosPickerItem) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Load the video as MovieTransferable
                guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
                    throw VideoPickerError.failedToLoad
                }

                await MainActor.run {
                    selectedVideoURL = movie.url
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load video: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

enum VideoPickerError: LocalizedError {
    case failedToLoad
    case notAVideo

    var errorDescription: String? {
        switch self {
        case .failedToLoad:
            return "Unable to load the selected video"
        case .notAVideo:
            return "The selected file is not a video"
        }
    }
}

#Preview {
    VideoPickerView(
        selectedVideoURL: .constant(nil),
        isLoading: .constant(false),
        errorMessage: .constant(nil)
    )
    .padding()
}
