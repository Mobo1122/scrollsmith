import SwiftUI

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
    /// Library, Types, Tags, and Trash share the library path since they
    /// operate on the same video collection with different filters.
    var currentPath: Binding<NavigationPath> {
        switch selectedSection {
        case .library, .types, .tags, .trash:
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
