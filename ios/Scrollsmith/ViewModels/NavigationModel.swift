import SwiftUI

/// Video type filter options for the Types sidebar section.
enum VideoType: String, CaseIterable, Identifiable {
    case youtube = "YouTube"
    case cameraRoll = "Camera Roll"
    case hasHabits = "Has Habits"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .youtube:
            return "play.rectangle.fill"
        case .cameraRoll:
            return "photo.on.rectangle"
        case .hasHabits:
            return "checkmark.circle.fill"
        }
    }
}

/// Observable navigation state management for sidebar-based navigation.
///
/// This class holds all navigation state including sidebar selection,
/// column visibility, and independent navigation paths per section.
/// Using @Observable ensures state persists across view rebuilds and
/// size class changes (critical for iPad rotation).
@Observable
final class NavigationModel {
    // MARK: - Sidebar State

    /// Currently selected sidebar section. Defaults to library.
    var selectedSection: SidebarSection? = .library

    /// Column visibility for NavigationSplitView.
    var columnVisibility: NavigationSplitViewVisibility = .automatic

    // MARK: - Filter State

    /// Currently selected video type filter (for Types section).
    var selectedType: VideoType?

    /// Currently selected playbook ID (for Playbooks section).
    var selectedPlaybookId: UUID?

    /// Currently selected playbook name (for display in navigation title).
    var selectedPlaybookName: String?

    /// Currently selected tag name (for Tags section).
    var selectedTag: String?

    // MARK: - Navigation Paths

    /// Navigation path for Library section (also used by Types, Tags, Trash).
    var libraryPath = NavigationPath()

    /// Navigation path for Playbooks section.
    var playbooksPath = NavigationPath()

    /// Navigation path for Habits section.
    var habitsPath = NavigationPath()

    /// Navigation path for Settings (accessible but not a sidebar section).
    var settingsPath = NavigationPath()

    // MARK: - Computed Properties

    /// Returns a binding to the appropriate navigation path based on current selection.
    ///
    /// Library, Tags, and Trash share the library path since they
    /// operate on the same video collection with different filters.
    var currentPath: Binding<NavigationPath> {
        switch selectedSection {
        case .library, .tags, .trash:
            return Binding(
                get: { self.libraryPath },
                set: { self.libraryPath = $0 }
            )
        case .playbooks:
            return Binding(
                get: { self.playbooksPath },
                set: { self.playbooksPath = $0 }
            )
        case .none:
            return Binding(
                get: { self.libraryPath },
                set: { self.libraryPath = $0 }
            )
        }
    }
}
