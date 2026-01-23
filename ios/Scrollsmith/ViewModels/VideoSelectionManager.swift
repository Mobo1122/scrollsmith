import Foundation
import SwiftUI

/// Observable manager for video multi-selection state.
///
/// Handles selection mode entry/exit, individual video selection toggling,
/// and bulk selection operations. Used by VideoGridView for bulk actions.
@Observable
final class VideoSelectionManager {
    // MARK: - State

    /// Whether selection mode is active.
    var isSelecting: Bool = false

    /// Set of currently selected video IDs.
    var selectedIds: Set<UUID> = []

    // MARK: - Computed Properties

    /// Number of currently selected videos.
    var selectedCount: Int { selectedIds.count }

    /// Whether any videos are selected.
    var hasSelection: Bool { !selectedIds.isEmpty }

    // MARK: - Selection Actions

    /// Toggles selection state for a video.
    ///
    /// If the video is selected, it will be deselected and vice versa.
    /// If no videos remain selected after toggle, exits selection mode.
    ///
    /// - Parameter id: The video ID to toggle
    func toggle(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }

        // Exit selection mode if nothing selected
        if selectedIds.isEmpty {
            isSelecting = false
        }
    }

    /// Enters selection mode with a specific video selected.
    ///
    /// Called on long-press of a video to start multi-select.
    ///
    /// - Parameter id: The initial video ID to select
    func enterSelectionMode(with id: UUID) {
        isSelecting = true
        selectedIds.insert(id)
    }

    /// Clears all selections and exits selection mode.
    func clearSelection() {
        selectedIds.removeAll()
        isSelecting = false
    }

    /// Selects all provided video IDs.
    ///
    /// - Parameter ids: Array of video IDs to select
    func selectAll(_ ids: [UUID]) {
        isSelecting = true
        selectedIds = Set(ids)
    }

    /// Checks if a specific video is selected.
    ///
    /// - Parameter id: The video ID to check
    /// - Returns: True if the video is selected
    func isSelected(_ id: UUID) -> Bool {
        selectedIds.contains(id)
    }
}
