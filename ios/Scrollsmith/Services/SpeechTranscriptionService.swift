import Speech
import AVFoundation

// MARK: - v2 TODO
// This service is DEFERRED TO v2 along with WhisperKit.
// For v1, transcription is done server-side via Whisper API or AssemblyAI.
//
// TODO v2: Enable this as fallback for WhisperKit on older iOS devices.

/// Fallback transcription service using Apple Speech framework.
///
/// **DEFERRED TO v2** - On-device transcription not used in v1.
///
/// Used on devices where WhisperKit is unavailable. Less accurate than WhisperKit
/// but works on iOS 14+ and supports on-device recognition for privacy.
@MainActor
class SpeechTranscriptionService: ObservableObject {

    static let shared = SpeechTranscriptionService()

    /// Progress of current transcription (0.0 to 1.0).
    @Published private(set) var transcriptionProgress: Double = 0

    /// Current authorization status.
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer: SFSpeechRecognizer?

    private init() {
        // Initialize with US English, with fallback to device locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            ?? SFSpeechRecognizer()
    }

    /// Checks if speech recognition is available on this device.
    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    /// Checks if on-device recognition is supported.
    var supportsOnDeviceRecognition: Bool {
        speechRecognizer?.supportsOnDeviceRecognition ?? false
    }

    /// Requests speech recognition authorization.
    ///
    /// - Returns: The authorization status after the request.
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                }
                continuation.resume(returning: status)
            }
        }
    }

    /// Transcribes an audio file using Speech framework.
    ///
    /// - Parameter audioURL: Local audio file URL.
    /// - Returns: Transcription text.
    /// - Throws: `SpeechTranscriptionError` if transcription fails.
    func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechTranscriptionError.recognizerNotAvailable
        }

        // Check authorization
        let status = await requestAuthorization()
        guard status == .authorized else {
            throw SpeechTranscriptionError.notAuthorized(status)
        }

        transcriptionProgress = 0

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        // Enable on-device recognition if available (iOS 13+)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            recognizer.recognitionTask(with: request) { [weak self] result, error in
                // Prevent multiple resumes
                guard !hasResumed else { return }

                if let error = error {
                    hasResumed = true
                    continuation.resume(throwing: SpeechTranscriptionError.recognitionFailed(error))
                    return
                }

                guard let result = result else {
                    return
                }

                // Update progress based on whether we have results
                Task { @MainActor in
                    self?.transcriptionProgress = result.isFinal ? 1.0 : 0.5
                }

                if result.isFinal {
                    hasResumed = true
                    let transcript = result.bestTranscription.formattedString

                    if transcript.isEmpty {
                        continuation.resume(throwing: SpeechTranscriptionError.emptyTranscript)
                    } else {
                        continuation.resume(returning: transcript)
                    }
                }
            }
        }
    }

    /// Resets the service state.
    func reset() {
        transcriptionProgress = 0
    }
}

/// Errors that can occur during Speech framework transcription.
enum SpeechTranscriptionError: LocalizedError {
    case recognizerNotAvailable
    case notAuthorized(SFSpeechRecognizerAuthorizationStatus)
    case recognitionFailed(Error)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognition is not available on this device"
        case .notAuthorized(let status):
            switch status {
            case .denied:
                return "Speech recognition permission was denied. Please enable it in Settings."
            case .restricted:
                return "Speech recognition is restricted on this device"
            case .notDetermined:
                return "Speech recognition permission not yet requested"
            case .authorized:
                return "Speech recognition is authorized"
            @unknown default:
                return "Speech recognition not authorized"
            }
        case .recognitionFailed(let error):
            return "Speech recognition failed: \(error.localizedDescription)"
        case .emptyTranscript:
            return "No speech detected in audio"
        }
    }

    /// Whether the user can fix this error by changing settings.
    var isRecoverable: Bool {
        switch self {
        case .notAuthorized(.denied):
            return true  // User can enable in Settings
        default:
            return false
        }
    }
}
