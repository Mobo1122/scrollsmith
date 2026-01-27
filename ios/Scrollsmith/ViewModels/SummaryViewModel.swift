import Foundation

/// Observable ViewModel for summary display state management.
///
/// Manages format switching, step completion persistence, and format availability.
/// Uses @Observable macro for automatic SwiftUI view updates.
@Observable
final class SummaryViewModel {
    // MARK: - State

    var currentFormat: SummaryFormat = .bullets
    var stepCompletionState: [Int: Bool] = [:]  // step_number: isComplete
    var cardProgress: Int = 0
    var isLoading = false
    var error: AppError?

    // MARK: - Private

    private let userDefaults = UserDefaults.standard
    private var currentVideoId: UUID?

    // MARK: - Step Completion

    /// Loads step completion state from UserDefaults for a specific video.
    ///
    /// Call this when navigating to a video detail view.
    ///
    /// - Parameter videoId: The video ID to load completion state for
    func loadStepCompletion(for videoId: UUID) {
        currentVideoId = videoId
        let key = stepCompletionKey(for: videoId)
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Int: Bool].self, from: data) {
            stepCompletionState = decoded
        } else {
            stepCompletionState = [:]
        }
    }

    /// Toggles the completion state for a specific step.
    ///
    /// - Parameter stepNumber: The step number to toggle
    func toggleStepCompletion(_ stepNumber: Int) {
        stepCompletionState[stepNumber, default: false].toggle()
        saveStepCompletion()
    }

    /// Checks if a specific step is marked as complete.
    ///
    /// - Parameter stepNumber: The step number to check
    /// - Returns: True if the step is marked complete
    func isStepComplete(_ stepNumber: Int) -> Bool {
        stepCompletionState[stepNumber] ?? false
    }

    /// Calculates the completion percentage for steps.
    ///
    /// - Parameter totalSteps: Total number of steps in the checklist
    /// - Returns: Completion percentage (0.0 - 1.0)
    func stepCompletionPercentage(totalSteps: Int) -> Double {
        guard totalSteps > 0 else { return 0 }
        let completed = stepCompletionState.values.filter { $0 }.count
        return Double(completed) / Double(totalSteps)
    }

    /// Saves step completion state to UserDefaults.
    private func saveStepCompletion() {
        guard let videoId = currentVideoId else { return }
        let key = stepCompletionKey(for: videoId)
        if let data = try? JSONEncoder().encode(stepCompletionState) {
            userDefaults.set(data, forKey: key)
        }
    }

    /// Generates the UserDefaults key for step completion state.
    private func stepCompletionKey(for videoId: UUID) -> String {
        "stepCompletion_\(videoId.uuidString)"
    }

    // MARK: - Format Availability

    /// Determines which summary formats are available for a video.
    ///
    /// Free users only see bullets format.
    /// Pro users see all formats that have data.
    ///
    /// - Parameters:
    ///   - video: The video DTO
    ///   - isPro: Whether the user has Pro subscription
    /// - Returns: Set of available formats
    func availableFormats(for video: VideoDTO, isPro: Bool) -> Set<SummaryFormat> {
        var formats: Set<SummaryFormat> = []

        if video.summaryBullets != nil {
            formats.insert(.bullets)
        }

        // Pro formats only available if user is Pro AND data exists
        if isPro {
            if video.summarySteps != nil {
                formats.insert(.steps)
            }
            if video.summaryCards != nil {
                formats.insert(.cards)
            }
        }

        return formats
    }

    /// Determines the best default format for a video.
    ///
    /// CONTEXT.md: Default to "best available" - Steps if actionable, Bullets otherwise.
    ///
    /// - Parameters:
    ///   - video: The video DTO
    ///   - isPro: Whether the user has Pro subscription
    /// - Returns: The recommended default format
    func bestDefaultFormat(for video: VideoDTO, isPro: Bool) -> SummaryFormat {
        // Steps are preferred for actionable content when available
        if isPro && video.summarySteps != nil {
            return .steps
        }
        return .bullets
    }

    /// Sets the current format, validating it's available.
    ///
    /// - Parameters:
    ///   - format: The desired format
    ///   - video: The video DTO (for validation)
    ///   - isPro: Whether the user has Pro subscription
    func setFormat(_ format: SummaryFormat, for video: VideoDTO, isPro: Bool) {
        let available = availableFormats(for: video, isPro: isPro)
        if available.contains(format) {
            currentFormat = format
        } else {
            // Fall back to best available format
            currentFormat = bestDefaultFormat(for: video, isPro: isPro)
        }
    }

    // MARK: - Reset

    /// Resets the view model state.
    func reset() {
        currentFormat = .bullets
        stepCompletionState = [:]
        cardProgress = 0
        isLoading = false
        error = nil
        currentVideoId = nil
    }

    /// Clears any error message.
    func clearError() {
        error = nil
    }
}
