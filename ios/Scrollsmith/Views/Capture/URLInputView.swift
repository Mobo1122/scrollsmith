import SwiftUI

// MARK: - v1 Architecture
// Only YouTube URLs are supported in v1 (caption fetching via youtube-transcript-api).
// TikTok/Instagram URL support is deferred to v2 when WhisperKit becomes available.
//
// TODO v2: Re-enable TikTok/Instagram URL validation and handling

/// A view for entering and validating video URLs.
///
/// **v1:** Only YouTube URLs are supported (caption fetching).
/// **v2:** Will add TikTok/Instagram support with on-device transcription.
///
/// Provides a text field with real-time validation feedback,
/// platform detection, and a paste button for convenience.
struct URLInputView: View {
    @Binding var urlText: String
    @Binding var validatedSource: VideoSource?

    @State private var validationState: ValidationState = .empty
    @FocusState private var isFocused: Bool

    enum ValidationState {
        case empty
        case invalid
        case unsupportedPlatform(VideoPlatform)  // v1: TikTok/IG detected but not supported
        case valid(VideoPlatform)

        var color: Color {
            switch self {
            case .empty:
                return .secondary
            case .invalid:
                return .red
            case .unsupportedPlatform:
                return .orange
            case .valid:
                return .green
            }
        }

        var message: String? {
            switch self {
            case .empty:
                return nil
            case .invalid:
                return "Invalid URL. Paste a YouTube link."
            case .unsupportedPlatform(let platform):
                // v1: TikTok/IG not supported yet
                return "\(platform.displayName) URL support coming soon! Save to camera roll instead."
            case .valid(let platform):
                return "\(platform.displayName) video detected"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Input field
            HStack {
                Image(systemName: platformIcon)
                    .foregroundColor(validationState.color)
                    .frame(width: 24)

                TextField("Paste YouTube URL", text: $urlText)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .onSubmit {
                        validateAndSubmit()
                    }

                // Paste button
                Button {
                    pasteFromClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                // Clear button
                if !urlText.isEmpty {
                    Button {
                        urlText = ""
                        validationState = .empty
                        validatedSource = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Validation feedback
            if let message = validationState.message {
                HStack {
                    Image(systemName: validationIcon)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                }
                .foregroundColor(validationState.color)
            }

            // Submit button (only for valid YouTube URLs in v1)
            if case .valid(.youtube) = validationState {
                Button {
                    validateAndSubmit()
                } label: {
                    Label("Fetch Captions", systemImage: "text.badge.checkmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)  // YouTube red
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .onChange(of: urlText) { _, newValue in
            validateURL(newValue)
        }
    }

    private var platformIcon: String {
        switch validationState {
        case .empty:
            return "link"
        case .invalid:
            return "exclamationmark.triangle"
        case .unsupportedPlatform(let platform):
            return platform.iconName
        case .valid(let platform):
            return platform.iconName
        }
    }

    private var validationIcon: String {
        switch validationState {
        case .empty:
            return "info.circle"
        case .invalid:
            return "exclamationmark.circle"
        case .unsupportedPlatform:
            return "clock"  // Coming soon
        case .valid:
            return "checkmark.circle"
        }
    }

    private func validateURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            validationState = .empty
            validatedSource = nil
            return
        }

        let normalized = VideoURLValidator.normalize(trimmed)
        let (isValid, platform) = VideoURLValidator.validate(normalized)

        if isValid {
            // v1: Only YouTube is supported
            if platform == .youtube {
                validationState = .valid(platform)
            } else {
                // TikTok/IG detected but not supported in v1
                // TODO v2: Change this to .valid(platform) when WhisperKit is enabled
                validationState = .unsupportedPlatform(platform)
                validatedSource = nil
            }
        } else {
            validationState = .invalid
            validatedSource = nil
        }
    }

    private func validateAndSubmit() {
        // v1: Only allow YouTube submissions
        guard case .valid(.youtube) = validationState else { return }

        let normalized = VideoURLValidator.normalize(urlText)
        validatedSource = .url(normalized, .youtube)
        isFocused = false
    }

    private func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            urlText = string
            validateURL(string)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        URLInputView(
            urlText: .constant(""),
            validatedSource: .constant(nil)
        )

        URLInputView(
            urlText: .constant("https://www.youtube.com/watch?v=abc123"),
            validatedSource: .constant(nil)
        )

        URLInputView(
            urlText: .constant("https://www.tiktok.com/@user/video/123"),
            validatedSource: .constant(nil)
        )

        URLInputView(
            urlText: .constant("invalid-url"),
            validatedSource: .constant(nil)
        )
    }
    .padding()
}
