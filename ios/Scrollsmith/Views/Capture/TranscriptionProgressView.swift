import SwiftUI

// MARK: - v1 Architecture
// Transcription is server-side only. WhisperKit model loading states removed for v1.
// TODO v2: Add back .loadingModel state content for WhisperKit

/// Shows transcription progress with state-specific messaging.
struct TranscriptionProgressView: View {
    @ObservedObject var orchestrator: TranscriptionOrchestrator
    let upload: PendingUpload?

    var body: some View {
        VStack(spacing: 16) {
            // Platform icon
            if let upload = upload {
                Image(systemName: upload.videoPlatform.iconName)
                    .font(.title2)
                    .foregroundColor(platformColor)
            }

            // Progress indicator
            ProgressView(value: orchestrator.progress) {
                stateLabel
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .progressViewStyle(.linear)
            .tint(progressColor)

            // State-specific content
            stateContent
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch orchestrator.state {
        case .idle:
            Text("Ready")
        case .uploading:
            Text("Uploading...")
        case .transcribing:
            Text("Transcribing...")
        case .saving:
            Text("Saving...")
        case .completed:
            Text("Complete!")
        case .failed:
            Text("Failed")
        case .unavailable:
            Text("Unavailable")
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch orchestrator.state {
        case .uploading:
            VStack(spacing: 8) {
                Text("Uploading to server")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Your video will be transcribed securely")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

        case .completed(let transcript):
            CompletedStateView(transcript: transcript)

        case .unavailable(let message):
            VStack(spacing: 8) {
                Image(systemName: "text.badge.xmark")
                    .foregroundColor(.orange)
                    .font(.title)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)

                Text("Try a different video or upload from camera roll")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.title)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)

                if upload?.canRetry == true {
                    Text("Tap to retry")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

        default:
            EmptyView()
        }
    }

    private var platformColor: Color {
        guard let upload = upload else { return .secondary }
        switch upload.videoPlatform {
        case .tiktok: return .pink
        case .instagram: return .purple
        case .youtube: return .red
        case .cameraRoll: return Theme.accent
        case .unknown: return .secondary
        }
    }

    private var progressColor: Color {
        switch orchestrator.state {
        case .failed: return .red
        case .completed: return .green
        case .unavailable: return .orange
        default: return .accentColor
        }
    }
}

/// Animated completion state with full celebration animation.
private struct CompletedStateView: View {
    let transcript: String

    @State private var showTranscript = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Full success animation with confetti
            SuccessAnimationView(
                title: "Processing Complete!",
                subtitle: nil,
                showConfetti: true
            )
            .frame(height: 140)

            // Transcript preview fades in after animation
            if showTranscript {
                Text(transcript.prefix(150) + (transcript.count > 150 ? "..." : ""))
                    .font(Typography.caption)
                    .foregroundColor(Theme.Text.secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            // Fade in transcript after success animation plays
            withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
                showTranscript = true
            }
        }
    }
}

/// Compact progress indicator for the capture tab.
struct CompactTranscriptionProgress: View {
    @ObservedObject var queueService: UploadQueueService

    var body: some View {
        if queueService.isProcessing, let upload = queueService.currentItem {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)

                Text(upload.statusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: upload.videoPlatform.iconName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
        }
    }
}

/// Model download progress overlay.
struct ModelDownloadOverlay: View {
    @ObservedObject var whisperKit: WhisperKitService

    var body: some View {
        if case .downloading(let progress) = whisperKit.modelState {
            VStack(spacing: 16) {
                ProgressView(value: progress) {
                    Text("Downloading AI Model")
                        .font(.headline)
                }
                .progressViewStyle(.linear)

                Text("This enables on-device transcription for privacy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("\(Int(progress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(40)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TranscriptionProgressView(
            orchestrator: TranscriptionOrchestrator.shared,
            upload: nil
        )

        CompactTranscriptionProgress(
            queueService: UploadQueueService.shared
        )
    }
    .padding()
}
