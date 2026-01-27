import Foundation
import SwiftUI

/// Observable ViewModel for Playbook state management.
///
/// Manages Playbook list, create/update/delete operations, and video assignment.
/// Uses @Observable macro for automatic SwiftUI view updates.
@Observable
final class PlaybookViewModel {
    // MARK: - State

    var playbooks: [PlaybookDTO] = []
    var isLoading: Bool = false
    var error: AppError?
    var lastSelectedPlaybookId: UUID?  // "Remember last selected" behavior

    // MARK: - Load Playbooks

    /// Fetches all Playbooks from the backend.
    func loadPlaybooks() async {
        isLoading = true
        error = nil

        do {
            playbooks = try await APIClient.shared.getPlaybooks()
        } catch {
            self.error = AppError.from(error)
            CrashReportingService.shared.captureError(error, context: ["action": "loadPlaybooks"])
        }

        isLoading = false
    }

    // MARK: - Create Playbook

    /// Creates a new Playbook with the given name and optional icon.
    ///
    /// - Parameters:
    ///   - name: The Playbook name
    ///   - icon: Optional SF Symbol name for the icon
    /// - Returns: True if creation succeeded
    func createPlaybook(name: String, icon: String? = nil) async -> Bool {
        do {
            let newPlaybook = try await APIClient.shared.createPlaybook(name: name, icon: icon)
            // Insert after Favorites (if present) or at the beginning
            if let favoritesIndex = playbooks.firstIndex(where: { $0.isSystem }) {
                playbooks.insert(newPlaybook, at: favoritesIndex + 1)
            } else {
                playbooks.insert(newPlaybook, at: 0)
            }
            return true
        } catch {
            self.error = AppError.from(error)
            CrashReportingService.shared.captureError(error, context: [
                "action": "createPlaybook",
                "name": name
            ])
            return false
        }
    }

    // MARK: - Update Playbook

    /// Updates an existing Playbook's name.
    ///
    /// - Parameters:
    ///   - id: The Playbook ID
    ///   - name: The new name
    /// - Returns: True if update succeeded
    func updatePlaybook(id: UUID, name: String) async -> Bool {
        do {
            let updated = try await APIClient.shared.updatePlaybook(id: id, name: name)
            if let index = playbooks.firstIndex(where: { $0.id == id }) {
                playbooks[index] = updated
            }
            return true
        } catch {
            self.error = AppError.from(error)
            CrashReportingService.shared.captureError(error, context: [
                "action": "updatePlaybook",
                "playbookId": id.uuidString
            ])
            return false
        }
    }

    // MARK: - Delete Playbook

    /// Deletes a Playbook by ID.
    ///
    /// Note: System Playbooks (like Favorites) cannot be deleted.
    ///
    /// - Parameter id: The Playbook ID
    /// - Returns: True if deletion succeeded
    func deletePlaybook(id: UUID) async -> Bool {
        do {
            try await APIClient.shared.deletePlaybook(id: id)
            playbooks.removeAll { $0.id == id }
            return true
        } catch {
            self.error = AppError.from(error)
            CrashReportingService.shared.captureError(error, context: [
                "action": "deletePlaybook",
                "playbookId": id.uuidString
            ])
            return false
        }
    }

    // MARK: - Assign Video

    /// Assigns a Video to a Playbook.
    ///
    /// Also updates lastSelectedPlaybookId for "remember last selected" behavior.
    ///
    /// - Parameters:
    ///   - videoId: The Video ID
    ///   - playbookId: The Playbook ID
    /// - Returns: True if assignment succeeded
    func assignVideo(_ videoId: UUID, to playbookId: UUID) async -> Bool {
        do {
            try await APIClient.shared.assignVideoToPlaybook(videoId: videoId, playbookId: playbookId)
            lastSelectedPlaybookId = playbookId  // Remember selection
            await loadPlaybooks()  // Refresh counts
            return true
        } catch {
            self.error = AppError.from(error)
            CrashReportingService.shared.captureError(error, context: [
                "action": "assignVideo",
                "videoId": videoId.uuidString,
                "playbookId": playbookId.uuidString
            ])
            return false
        }
    }

    /// Removes a Video from a Playbook.
    ///
    /// - Parameters:
    ///   - videoId: The Video ID
    ///   - playbookId: The Playbook ID
    /// - Returns: True if removal succeeded
    func removeVideo(_ videoId: UUID, from playbookId: UUID) async -> Bool {
        do {
            try await APIClient.shared.removeVideoFromPlaybook(videoId: videoId, playbookId: playbookId)
            await loadPlaybooks()  // Refresh counts
            return true
        } catch {
            self.error = AppError.from(error)
            CrashReportingService.shared.captureError(error, context: [
                "action": "removeVideo",
                "videoId": videoId.uuidString,
                "playbookId": playbookId.uuidString
            ])
            return false
        }
    }

    // MARK: - Helpers

    /// The Favorites Playbook (system-created, cannot be deleted).
    var favoritesPlaybook: PlaybookDTO? {
        playbooks.first { $0.isSystem && $0.name == "Favorites" }
    }

    /// User-created Playbooks (excludes system Playbooks like Favorites).
    var userPlaybooks: [PlaybookDTO] {
        playbooks.filter { !$0.isSystem }
    }

    /// Clears any error message.
    func clearError() {
        error = nil
    }
}
