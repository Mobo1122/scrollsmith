import Foundation
import Observation

/// ViewModel for managing user's tags with video counts.
/// Fetches tag data from backend API for sidebar display.
@Observable
class TagViewModel {
    // MARK: - Properties

    /// List of user's tags with video counts
    var tags: [TagDTO] = []

    /// Loading state
    var isLoading = false

    /// Error message if loading fails
    var errorMessage: String?

    // MARK: - Methods

    /// Loads all tags with video counts from the backend.
    /// Tags are sorted by videoCount (most used first).
    @MainActor
    func loadTags() async {
        isLoading = true
        errorMessage = nil

        do {
            tags = try await APIClient.shared.getTags()
        } catch {
            errorMessage = "Failed to load tags: \(error.localizedDescription)"
            print("❌ TagViewModel: Failed to load tags - \(error)")
        }

        isLoading = false
    }

    /// Clears all loaded tags (useful for logout)
    func clearTags() {
        tags = []
        errorMessage = nil
    }
}
