import SwiftUI

/// Main capture view with options for camera roll and URL input.
///
/// Provides a tabbed interface for selecting videos from different sources.
/// Camera roll uses PhotosPicker, URL uses text input with validation.
struct CaptureView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var uploadQueueService: UploadQueueService
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: CaptureTab = .cameraRoll
    @State private var selectedVideoURL: URL?
    @State private var urlText: String = ""
    @State private var validatedURLSource: VideoSource?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    enum CaptureTab: String, CaseIterable {
        case cameraRoll = "Camera Roll"
        case url = "Paste URL"

        var icon: String {
            switch self {
            case .cameraRoll:
                return "photo.on.rectangle"
            case .url:
                return "link"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Processing indicator
                if uploadQueueService.isProcessing {
                    UploadProgressView()
                        .padding(.horizontal)
                }

                // Tab selector
                Picker("Source", selection: $selectedTab) {
                    ForEach(CaptureTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Content based on selected tab
                switch selectedTab {
                case .cameraRoll:
                    cameraRollContent
                case .url:
                    urlContent
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Video")
            .toolbar {
                if uploadQueueService.pendingCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            PendingUploadsListView()
                                .navigationTitle("Pending")
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "tray")
                                PendingUploadBadge(count: uploadQueueService.pendingCount)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showConfirmation) {
                if let url = selectedVideoURL {
                    VideoConfirmationSheet(
                        videoURL: url,
                        onConfirm: {
                            processVideo(source: .localFile(url))
                        },
                        onCancel: {
                            cancelSelection()
                        }
                    )
                }
            }
            .onChange(of: selectedVideoURL) { _, newValue in
                if newValue != nil {
                    showConfirmation = true
                }
            }
            .onChange(of: validatedURLSource) { _, newValue in
                if let source = newValue {
                    processVideo(source: source)
                }
            }
        }
    }

    // MARK: - Camera Roll Tab

    private var cameraRollContent: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(Theme.accent.opacity(0.8))

            Text("Select a video from your camera roll")
                .font(Typography.headline)
                .multilineTextAlignment(.center)

            Text("The video will be transcribed and summarized using AI.")
                .font(Typography.subheadline)
                .foregroundColor(Theme.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VideoPickerView(
                selectedVideoURL: $selectedVideoURL,
                isLoading: $isLoading,
                errorMessage: $errorMessage
            )
            .padding(.horizontal)

            if isLoading {
                ProgressView("Loading video...")
                    .tint(Theme.accent)
            }

            if let error = errorMessage {
                Text(error)
                    .font(Typography.footnote)
                    .foregroundColor(Theme.Semantic.error)
            }
        }
        .padding()
    }

    // MARK: - URL Tab

    // v1: Only YouTube URLs supported (caption fetching)
    // TODO v2: Add TikTok/Instagram URL support with on-device WhisperKit transcription
    private var urlContent: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.accent.opacity(0.8))

            Text("Paste a YouTube URL")
                .font(Typography.headline)
                .multilineTextAlignment(.center)

            Text("YouTube videos with captions will be transcribed automatically.")
                .font(Typography.subheadline)
                .foregroundColor(Theme.Text.secondary)
                .multilineTextAlignment(.center)

            URLInputView(
                urlText: $urlText,
                validatedSource: $validatedURLSource
            )
            .padding(.horizontal)

            // v1: Hint about TikTok/IG workaround
            VStack(spacing: Spacing.xs) {
                Divider()
                    .padding(.vertical, Spacing.xs)

                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.Text.secondary)
                    Text("TikTok & Instagram")
                        .font(Typography.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Text.secondary)
                }

                Text("Save the video to your camera roll first, then upload from there.")
                    .font(Typography.footnote)
                    .foregroundColor(Theme.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Actions

    private func processVideo(source: VideoSource) {
        showConfirmation = false

        // Create source URL string based on source type
        let sourceURLString: String
        let platform: String

        switch source {
        case .localFile(let url):
            sourceURLString = url.absoluteString
            platform = VideoPlatform.cameraRoll.rawValue
        case .url(let urlString, let videoPlatform):
            sourceURLString = urlString
            platform = videoPlatform.rawValue
        }

        // Create PendingUpload record
        let pendingUpload = PendingUpload(
            sourceURL: sourceURLString,
            platform: platform
        )
        modelContext.insert(pendingUpload)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to queue video: \(error.localizedDescription)"
            return
        }

        // Trigger the upload queue
        Task {
            await uploadQueueService.refreshPendingCount()
            await uploadQueueService.processQueue()
        }

        // Reset state
        selectedVideoURL = nil
        urlText = ""
        validatedURLSource = nil
        errorMessage = nil
    }

    private func cancelSelection() {
        showConfirmation = false

        // Clean up temp file if from camera roll
        if let url = selectedVideoURL {
            VideoFileManager.cleanup(url: url)
        }

        selectedVideoURL = nil
    }
}

#Preview {
    CaptureView()
        .environmentObject(AuthViewModel())
        .environmentObject(UploadQueueService.shared)
}
