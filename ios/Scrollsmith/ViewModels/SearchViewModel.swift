import Foundation
import SwiftUI

/// Observable ViewModel for video search with debouncing.
///
/// Provides debounced search (250ms) to avoid excessive API calls while typing.
/// Supports optional playbook scoping for contextual search.
@Observable
final class SearchViewModel {
    // MARK: - State

    /// The current search text entered by the user.
    var searchText: String = ""

    /// The debounced query that will be sent to the API.
    var debouncedQuery: String = ""

    /// Whether a search is currently in progress.
    var isSearching: Bool = false

    /// Search results from the API.
    var results: [VideoSearchResult] = []

    /// Error message if search failed.
    var error: AppError?

    /// Optional playbook ID to scope search to a specific playbook.
    var playbookId: UUID?

    // MARK: - Private

    private var searchTask: Task<Void, Never>?

    // MARK: - Debounced Search

    /// Called when search text changes. Debounces the input and triggers search.
    ///
    /// Uses a 250ms debounce to avoid excessive API calls while typing.
    ///
    /// - Parameter newValue: The new search text
    func onSearchTextChanged(_ newValue: String) {
        searchTask?.cancel()

        if newValue.isEmpty {
            debouncedQuery = ""
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                debouncedQuery = newValue
            }
        }
    }

    // MARK: - Perform Search

    /// Performs the search using the debounced query.
    ///
    /// Called automatically when debouncedQuery changes.
    func performSearch() async {
        guard !debouncedQuery.isEmpty else { return }

        isSearching = true
        error = nil

        do {
            results = try await APIClient.shared.searchVideos(
                query: debouncedQuery,
                playbookId: playbookId
            )
        } catch {
            self.error = AppError.from(error)
            CrashReportingService.shared.captureError(error, context: [
                "action": "searchVideos",
                "query": debouncedQuery
            ])
            results = []
        }

        isSearching = false
    }

    /// Clears the search state.
    func clearSearch() {
        searchText = ""
        debouncedQuery = ""
        results = []
        searchTask?.cancel()
        error = nil
    }
}
