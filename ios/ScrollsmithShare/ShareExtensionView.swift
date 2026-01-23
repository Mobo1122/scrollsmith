import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// SwiftUI view for the Share Extension.
///
/// Displays shared content and allows the user to save it to Scrollsmith.
/// Supports both URL sharing (TikTok, Instagram, YouTube) and video files.
struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @Environment(\.modelContext) private var modelContext

    @State private var sharedURL: URL?
    @State private var sharedText: String?
    @State private var detectedPlatform: VideoPlatform = .unknown
    @State private var isProcessing = false
    @State private var savedSuccessfully = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessing {
                    processingView
                } else if savedSuccessfully {
                    successView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .padding()
            .navigationTitle("Scrollsmith")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                }
                if !savedSuccessfully && errorMessage == nil && !isProcessing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveVideo()
                        }
                        .disabled(sharedURL == nil && sharedText == nil)
                    }
                }
            }
        }
        .task {
            await extractSharedContent()
        }
    }

    // MARK: - Views

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Saving...")
                .font(.headline)
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Saved to Scrollsmith")
                .font(.headline)

            Text("Open the app to process this video.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                complete()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Unable to Save")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                errorMessage = nil
                Task {
                    await extractSharedContent()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var contentView: some View {
        VStack(spacing: 20) {
            // Platform icon
            Image(systemName: detectedPlatform.iconName)
                .font(.system(size: 50))
                .foregroundColor(.blue)

            if detectedPlatform != .unknown {
                Text("\(detectedPlatform.displayName) Video")
                    .font(.headline)
            } else {
                Text("Video URL")
                    .font(.headline)
            }

            // URL display
            if let url = sharedURL {
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else if let text = sharedText {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text("No video URL detected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("The video will be added to your queue for processing.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func extractSharedContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            await MainActor.run {
                errorMessage = "No content received"
            }
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Try to load as URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        await processURL(url)
                        return
                    }
                }

                // Try to load as plain text (URL as string)
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                        await processText(text)
                        return
                    }
                }
            }
        }

        await MainActor.run {
            errorMessage = "Could not find a supported video URL"
        }
    }

    private func processURL(_ url: URL) async {
        let urlString = url.absoluteString
        let (isValid, platform) = VideoURLValidator.validate(urlString)

        await MainActor.run {
            if isValid {
                self.sharedURL = url
                self.detectedPlatform = platform
            } else {
                // Still allow saving, but mark as unknown
                self.sharedURL = url
                self.detectedPlatform = .unknown
            }
        }
    }

    private func processText(_ text: String) async {
        let normalized = VideoURLValidator.normalize(text)
        let (isValid, platform) = VideoURLValidator.validate(normalized)

        await MainActor.run {
            if isValid, let url = URL(string: normalized) {
                self.sharedURL = url
                self.detectedPlatform = platform
            } else {
                self.sharedText = text
                self.detectedPlatform = .unknown
            }
        }
    }

    private func saveVideo() {
        guard sharedURL != nil || sharedText != nil else { return }

        isProcessing = true

        let urlString: String
        if let url = sharedURL {
            urlString = url.absoluteString
        } else if let text = sharedText {
            urlString = VideoURLValidator.normalize(text)
        } else {
            isProcessing = false
            errorMessage = "No URL to save"
            return
        }

        // Create pending upload record
        let pendingUpload = PendingUpload(
            sourceURL: urlString,
            platform: detectedPlatform.rawValue
        )

        modelContext.insert(pendingUpload)

        do {
            try modelContext.save()
            savedSuccessfully = true
            isProcessing = false
        } catch {
            isProcessing = false
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.scrollsmith.share",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "User cancelled"]
        ))
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

#Preview {
    ShareExtensionView(extensionContext: nil)
}
