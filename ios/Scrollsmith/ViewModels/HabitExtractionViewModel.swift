import Foundation
import SwiftUI

/// ViewModel for habit extraction flow.
///
/// Manages:
/// - Extracting habits from video transcript
/// - Tracking selection state for each suggestion
/// - Creating selected habits with chosen frequencies
///
/// Flow: extract -> user selects -> user confirms frequencies -> create habits
@MainActor
@Observable
class HabitExtractionViewModel {
    // MARK: - State

    /// Current extraction state
    enum State: Equatable {
        case idle
        case loading
        case suggestions([HabitSelectionState])
        case creating
        case success(created: Int)
        case error(String)
        case proRequired

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.loading, .loading): return true
            case (.creating, .creating): return true
            case (.proRequired, .proRequired): return true
            case (.success(let a), .success(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            case (.suggestions(let a), .suggestions(let b)):
                return a.map { $0.id } == b.map { $0.id }
            default: return false
            }
        }
    }

    var state: State = .idle

    /// Convenience computed properties
    var isLoading: Bool {
        if case .loading = state { return true }
        if case .creating = state { return true }
        return false
    }

    var suggestions: [HabitSelectionState] {
        if case .suggestions(let items) = state { return items }
        return []
    }

    var selectedCount: Int {
        suggestions.filter { $0.isSelected }.count
    }

    var hasSelections: Bool {
        selectedCount > 0
    }

    // MARK: - Private

    private let apiClient = APIClient.shared
    private var videoId: UUID?

    // MARK: - Actions

    /// Extract habits from a video transcript.
    ///
    /// Call this when user taps "Make action points" button.
    /// Updates state to .suggestions on success.
    func extractHabits(from videoId: UUID) async {
        self.videoId = videoId
        state = .loading

        do {
            let response = try await apiClient.extractHabits(videoId: videoId)

            // Convert suggestions to selection states (all selected by default)
            let selectionStates = response.suggestions.map { suggestion in
                HabitSelectionState(suggestion: suggestion, isSelected: true)
            }

            state = .suggestions(selectionStates)
        } catch APIError.proRequired {
            state = .proRequired
        } catch {
            state = .error(AppError.from(error).localizedDescription)
            CrashReportingService.shared.captureError(error, context: [
                "action": "extractHabits",
                "videoId": videoId.uuidString
            ])
        }
    }

    /// Toggle selection state for a suggestion.
    func toggleSelection(for suggestionId: String) {
        guard case .suggestions(var items) = state else { return }

        if let index = items.firstIndex(where: { $0.id == suggestionId }) {
            items[index].isSelected.toggle()
            state = .suggestions(items)
        }
    }

    /// Update frequency for a suggestion.
    func updateFrequency(for suggestionId: String, to frequency: HabitFrequency) {
        guard case .suggestions(var items) = state else { return }

        if let index = items.firstIndex(where: { $0.id == suggestionId }) {
            items[index].frequency = frequency
            state = .suggestions(items)
        }
    }

    /// Create habits for all selected suggestions.
    ///
    /// Call this when user taps "Create Habits" button.
    /// Creates each selected habit with its configured frequency.
    func createSelectedHabits() async {
        guard let videoId = videoId else {
            state = .error("Video ID not set")
            return
        }

        let selectedItems = suggestions.filter { $0.isSelected }
        guard !selectedItems.isEmpty else {
            state = .error("No habits selected")
            return
        }

        state = .creating

        var createdCount = 0
        var lastError: Error?

        for item in selectedItems {
            do {
                _ = try await apiClient.createHabit(
                    videoId: videoId,
                    title: item.suggestion.title,
                    frequency: item.frequency
                )
                createdCount += 1
            } catch {
                lastError = error
                // Continue creating other habits even if one fails
            }
        }

        if createdCount > 0 {
            state = .success(created: createdCount)
        } else if let error = lastError {
            state = .error(AppError.from(error).localizedDescription)
            CrashReportingService.shared.captureError(error, context: [
                "action": "createSelectedHabits",
                "videoId": videoId.uuidString,
                "selectedCount": selectedItems.count
            ])
        } else {
            state = .error("Failed to create habits")
        }
    }

    /// Reset state to idle.
    func reset() {
        state = .idle
        videoId = nil
    }
}
