import Foundation
import SwiftUI

#if canImport(WhisperKit)
import WhisperKit
#endif

// MARK: - v2 TODO
// This service is DEFERRED TO v2. On-device WhisperKit transcription requires macOS 14+
// for the toolchain, but the dev machine is currently on macOS 13.
//
// For v1, transcription is done server-side via Whisper API or AssemblyAI.
// Users should download TikTok/Instagram videos to camera roll and upload from there.
//
// TODO v2: Enable this service once dev environment is on macOS 14+:
// 1. Add WhisperKit via SPM: https://github.com/argmaxinc/WhisperKit
// 2. Add Speech permission to Info.plist
// 3. Update TranscriptionOrchestrator to use this for TikTok/IG URLs

/// On-device transcription service using WhisperKit.
///
/// **DEFERRED TO v2** - WhisperKit requires macOS 14+ for the toolchain.
///
/// WhisperKit provides fast, private on-device transcription using Apple's CoreML.
/// Requires iOS 17+ and downloads ML models (~75-150MB) on first use.
///
/// - Important: WhisperKit must be added via SPM before this service will function.
///   URL: https://github.com/argmaxinc/WhisperKit
@MainActor
class WhisperKitService: ObservableObject {

    static let shared = WhisperKitService()

    /// Current state of the WhisperKit model.
    enum ModelState: Equatable {
        case notLoaded
        case downloading(progress: Double)
        case loading
        case ready
        case failed(message: String)

        static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.notLoaded, .notLoaded): return true
            case (.downloading(let a), .downloading(let b)): return a == b
            case (.loading, .loading): return true
            case (.ready, .ready): return true
            case (.failed(let a), .failed(let b)): return a == b
            default: return false
            }
        }
    }

    /// Current model state.
    @Published private(set) var modelState: ModelState = .notLoaded

    /// Progress of current transcription (0.0 to 1.0).
    @Published private(set) var transcriptionProgress: Double = 0

    #if canImport(WhisperKit)
    private var whisperKit: WhisperKit?
    #endif

    /// Recommended model based on device capability.
    ///
    /// Uses "tiny" (~75MB) for devices with <6GB RAM, "base" (~150MB) for others.
    private var recommendedModel: String {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        // Use base model for devices with 6GB+ RAM (iPhone 15 Pro, etc.)
        if physicalMemory >= 6_000_000_000 {
            return "openai_whisper-base"
        }
        return "openai_whisper-tiny"
    }

    private init() {}

    /// Checks if WhisperKit is available on this device and build.
    static var isAvailable: Bool {
        #if canImport(WhisperKit)
        // WhisperKit requires iOS 17+
        if #available(iOS 17.0, *) {
            return true
        }
        #endif
        return false
    }

    /// Ensures the WhisperKit model is loaded, downloading if necessary.
    ///
    /// Call this before transcription. On first use, downloads the ML model
    /// which may take 30-60 seconds depending on network speed.
    ///
    /// - Throws: `WhisperKitError` if model loading fails.
    func ensureModelLoaded() async throws {
        #if canImport(WhisperKit)
        guard #available(iOS 17.0, *) else {
            throw WhisperKitError.notSupported
        }

        if whisperKit != nil {
            return
        }

        modelState = .downloading(progress: 0)

        do {
            // Initialize WhisperKit with progress callback
            let config = WhisperKitConfig(
                model: recommendedModel,
                verbose: false,
                logLevel: .none,
                prewarm: true,
                load: true,
                download: true
            )

            let kit = try await WhisperKit(config) { progress in
                Task { @MainActor in
                    self.modelState = .downloading(progress: progress.fractionCompleted)
                }
            }

            whisperKit = kit
            modelState = .ready

        } catch {
            let message = error.localizedDescription
            modelState = .failed(message: message)
            throw WhisperKitError.modelLoadFailed(error)
        }
        #else
        throw WhisperKitError.notSupported
        #endif
    }

    /// Transcribes an audio file.
    ///
    /// - Parameter audioURL: Local audio file URL (M4A, WAV, MP3, etc.)
    /// - Returns: Transcription text.
    /// - Throws: `WhisperKitError` if transcription fails.
    func transcribe(audioURL: URL) async throws -> String {
        #if canImport(WhisperKit)
        guard #available(iOS 17.0, *) else {
            throw WhisperKitError.notSupported
        }

        guard let kit = whisperKit else {
            throw WhisperKitError.modelNotLoaded
        }

        transcriptionProgress = 0

        do {
            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: nil,  // Auto-detect language
                temperature: 0,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                suppressBlank: true,
                compressionRatioThreshold: 2.4,
                logProbThreshold: -1.0,
                noSpeechThreshold: 0.6
            )

            let results = try await kit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            ) { progress in
                Task { @MainActor in
                    self.transcriptionProgress = progress.fractionCompleted
                }
            }

            transcriptionProgress = 1.0

            // Combine all segments
            let text = results
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if text.isEmpty {
                throw WhisperKitError.emptyTranscript
            }

            return text

        } catch let error as WhisperKitError {
            throw error
        } catch {
            throw WhisperKitError.transcriptionFailed(error)
        }
        #else
        throw WhisperKitError.notSupported
        #endif
    }

    /// Resets the service state (for testing/debugging).
    func reset() {
        #if canImport(WhisperKit)
        whisperKit = nil
        #endif
        modelState = .notLoaded
        transcriptionProgress = 0
    }
}

/// Errors that can occur with WhisperKit transcription.
enum WhisperKitError: LocalizedError {
    case notSupported
    case modelNotLoaded
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "WhisperKit is not available on this device"
        case .modelNotLoaded:
            return "Transcription model not loaded. Call ensureModelLoaded() first."
        case .modelLoadFailed(let error):
            return "Failed to load transcription model: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .emptyTranscript:
            return "No speech detected in audio"
        }
    }
}
