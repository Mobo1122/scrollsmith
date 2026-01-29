import Foundation

/// Type-safe enum defining all sidebar sections for navigation.
///
/// Each case represents a top-level section in the sidebar with
/// associated icon and display title.
enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case library = "Library"
    case types = "Types"
    case playbooks = "Playbooks"
    case tags = "Tags"
    case trash = "Trash"

    /// Unique identifier for Identifiable conformance.
    var id: String { rawValue }

    /// SF Symbol name for the section icon.
    var icon: String {
        switch self {
        case .library: return "books.vertical"
        case .types: return "square.stack.3d.up"
        case .playbooks: return "folder"
        case .tags: return "tag"
        case .trash: return "trash"
        }
    }

    /// Display title for the section.
    var title: String { rawValue }
}
