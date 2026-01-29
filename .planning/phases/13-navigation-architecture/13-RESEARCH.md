# Phase 13: Navigation Architecture - Research

**Researched:** 2026-01-29
**Domain:** SwiftUI NavigationSplitView Sidebar Navigation (iOS 17+)
**Confidence:** HIGH

## Summary

Phase 13 replaces Scrollsmith's tab-based navigation (MainTabView) with a sidebar-based NavigationSplitView layout. This is a foundational architectural change that enables the Readwise Reader-inspired UI for v1.1. The implementation uses Apple's native NavigationSplitView which automatically adapts between iPhone (collapsed stack with overlay sidebar) and iPad (persistent split-view sidebar).

The critical success factor is correctly implementing selection binding and navigation state management from day one. NavigationSplitView has subtle requirements that, if missed, cause navigation to completely fail (sidebar appears to work but nothing happens when tapped). The prior v1.1 research identified this as Pitfall #1 and it must be addressed immediately during implementation.

The recommended approach creates 4-5 new files (NavigationModel, RootNavigationView, SidebarView, SidebarSection enum, and optionally DetailRouter) while preserving all 30+ existing view files unchanged. The migration is low-risk because existing views (PlaybookListView, VideoGridView, HabitListView, SettingsView) are simply wrapped in the new navigation container rather than modified.

**Primary recommendation:** Use two-column NavigationSplitView with @Observable NavigationModel class for state management, explicitly binding List selection in sidebar, and using SceneStorage for state persistence across app lifecycle.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| NavigationSplitView | iOS 16+ | Two/three column layout | Apple's official sidebar navigation pattern; automatically adapts iPhone/iPad |
| NavigationStack | iOS 16+ | Detail navigation | Enables drill-down within detail column while preserving state |
| @Observable | iOS 17+ | State management | Modern SwiftUI observation; replaces @StateObject for cleaner code |
| SceneStorage | iOS 14+ | State persistence | Automatic state restoration across app lifecycle |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| NavigationSplitViewVisibility | iOS 16+ | Column visibility control | Programmatic sidebar show/hide |
| NavigationSplitViewColumn | iOS 17+ | Compact column preference | Control which column shows on iPhone |
| List with selection | iOS 16+ | Sidebar content | Required for selection binding pattern |
| @Environment(\.horizontalSizeClass) | iOS 13+ | Size class detection | Conditionally adjust UI for compact/regular |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NavigationSplitView | TabView with sidebar tab | Would require custom iPad layout; NavigationSplitView handles this automatically |
| @Observable class | @StateObject + ObservableObject | Older pattern; @Observable is cleaner for iOS 17+ |
| SceneStorage | Manual UserDefaults | SceneStorage provides automatic per-scene persistence |

**No external dependencies required.** All components are native SwiftUI available in iOS 17+.

## Architecture Patterns

### Recommended Project Structure
```
Views/
  Navigation/
    RootNavigationView.swift      # NavigationSplitView container
    SidebarView.swift             # Sidebar content (List with sections)
    SidebarSection.swift          # Enum defining sidebar items
ViewModels/
  NavigationModel.swift           # @Observable navigation state
```

### Pattern 1: Observable Navigation Model
**What:** Centralized @Observable class managing navigation state
**When to use:** Always for NavigationSplitView to ensure state persists across size class changes
**Example:**
```swift
// Source: Apple WWDC22 "The SwiftUI cookbook for navigation" + fatbobman.com
@Observable
final class NavigationModel {
    // Sidebar selection - drives which detail view is shown
    var selectedSection: SidebarSection? = .library

    // Column visibility for programmatic control
    var columnVisibility: NavigationSplitViewVisibility = .automatic

    // Independent navigation paths per section (prevents state reset)
    var libraryPath = NavigationPath()
    var playbooksPath = NavigationPath()
    var habitsPath = NavigationPath()
    var settingsPath = NavigationPath()

    // Helper to get current path based on selection
    var currentPath: Binding<NavigationPath> {
        switch selectedSection {
        case .library, .types, .tags, .trash:
            return Binding(get: { self.libraryPath }, set: { self.libraryPath = $0 })
        case .playbooks:
            return Binding(get: { self.playbooksPath }, set: { self.playbooksPath = $0 })
        case .habits:
            return Binding(get: { self.habitsPath }, set: { self.habitsPath = $0 })
        case .settings:
            return Binding(get: { self.settingsPath }, set: { self.settingsPath = $0 })
        case .none:
            return Binding(get: { self.libraryPath }, set: { self.libraryPath = $0 })
        }
    }
}
```

### Pattern 2: Sidebar Section Enum
**What:** Type-safe enum defining all sidebar sections
**When to use:** Always for NavigationSplitView to enable safe switching and routing
**Example:**
```swift
// Source: Apple documentation pattern
enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case library = "Library"
    case types = "Types"
    case playbooks = "Playbooks"
    case tags = "Tags"
    case trash = "Trash"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library: return "books.vertical"
        case .types: return "square.stack.3d.up"
        case .playbooks: return "folder"
        case .tags: return "tag"
        case .trash: return "trash"
        }
    }

    var title: String { rawValue }
}
```

### Pattern 3: Two-Column NavigationSplitView with Selection Binding
**What:** The core navigation container pattern
**When to use:** Always as the root navigation structure
**Example:**
```swift
// Source: swiftwithmajid.com + Apple TN3154
struct RootNavigationView: View {
    @State private var navigationModel = NavigationModel()

    var body: some View {
        NavigationSplitView(columnVisibility: $navigationModel.columnVisibility) {
            // CRITICAL: Explicit selection binding on List
            List(selection: $navigationModel.selectedSection) {
                SidebarContent()
            }
            .navigationTitle("Scrollsmith")
        } detail: {
            // NavigationStack in detail for drill-down
            NavigationStack(path: navigationModel.currentPath) {
                DetailView(section: navigationModel.selectedSection)
                    .navigationDestination(for: VideoDTO.self) { video in
                        SummaryDisplayView(video: video)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced) // iPad: side-by-side
    }
}
```

### Pattern 4: Sidebar Content with Sections
**What:** Grouped List content for sidebar
**When to use:** For organized sidebar with multiple sections
**Example:**
```swift
// Source: Apple Mail/Notes pattern
struct SidebarContent: View {
    var body: some View {
        Section("Library") {
            Label("All Videos", systemImage: "books.vertical")
                .tag(SidebarSection.library)
        }

        Section("Filters") {
            Label("Types", systemImage: "square.stack.3d.up")
                .tag(SidebarSection.types)
            Label("Tags", systemImage: "tag")
                .tag(SidebarSection.tags)
        }

        Section("Organization") {
            Label("Playbooks", systemImage: "folder")
                .tag(SidebarSection.playbooks)
        }

        Section {
            Label("Trash", systemImage: "trash")
                .tag(SidebarSection.trash)
        }
    }
}
```

### Pattern 5: iPhone Compact Handling
**What:** Control which column shows when collapsed
**When to use:** iPhone displays NavigationSplitView as a stack; control initial view
**Example:**
```swift
// Source: hackingwithswift.com
struct RootNavigationView: View {
    @State private var preferredColumn = NavigationSplitViewColumn.detail
    @State private var navigationModel = NavigationModel()

    var body: some View {
        NavigationSplitView(
            columnVisibility: $navigationModel.columnVisibility,
            preferredCompactColumn: $preferredColumn
        ) {
            // sidebar
        } detail: {
            // detail - shows first on iPhone
        }
    }
}
```

### Anti-Patterns to Avoid
- **View-local @State for selection:** Causes state reset on iPad rotation and size class changes. Use @Observable class instead.
- **NavigationLink(destination:) in sidebar:** Deprecated pattern; use value-based NavigationLink with .navigationDestination()
- **Mixing NavigationStack with preferredCompactColumn changes:** Known bug causes navigation to break. Stick to selection-based navigation.
- **Forgetting selection binding on List:** Sidebar will highlight items but navigation won't work. Always bind `List(selection: $model.selectedSection)`.
- **Using NavigationSplitView inside NavigationStack:** NavigationSplitView should be root; embed NavigationStack in detail column only.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| iPhone/iPad sidebar adaptation | Custom size class switching | NavigationSplitView | Automatically handles compact/regular; tested edge cases |
| Navigation state persistence | Manual UserDefaults | SceneStorage | Per-scene automatic persistence; handles multi-window |
| Sidebar section routing | Switch statements in View | Enum + tag() | Type-safe, exhaustive, maintainable |
| Column visibility toggle | Custom sheet/overlay | NavigationSplitViewVisibility | Native animation, respects system settings |
| Navigation history | Array<View> management | NavigationPath | Type-erased, Codable, handles back navigation |

**Key insight:** NavigationSplitView is complex under the hood (handles multiple layout modes, size class transitions, rotation, keyboard avoidance). Custom implementations inevitably miss edge cases that Apple has tested. Trust the native component and work within its patterns.

## Common Pitfalls

### Pitfall 1: Selection Binding Forgotten (CRITICAL)
**What goes wrong:** Sidebar items highlight on tap but detail view never updates. Navigation appears completely broken.
**Why it happens:** List exists but selection isn't bound to state. SwiftUI highlights the row but has no mechanism to update detail.
**How to avoid:** ALWAYS use `List(selection: $navigationModel.selectedSection)` - the selection binding is mandatory.
**Warning signs:** Items highlight briefly then nothing happens. Detail view stays static.
**Test immediately:** First thing after implementing sidebar - tap an item and verify detail changes.

### Pitfall 2: Navigation State Reset on Rotation
**What goes wrong:** User drills into video summary, rotates iPad, and finds themselves back at root. Navigation history lost.
**Why it happens:** Using view-local @State for NavigationPath. Size class change causes view rebuild, resetting state.
**How to avoid:** Store NavigationPath in @Observable class, not @State. Use path dictionary pattern (one path per sidebar section).
**Warning signs:** Rotating iPad in landscape to portrait resets navigation.
**Test immediately:** Navigate 2-3 levels deep, rotate device, verify position preserved.

### Pitfall 3: preferredCompactColumn Bug with NavigationStack
**What goes wrong:** Programmatically changing preferredCompactColumn after pushing onto NavigationStack causes navigation to freeze.
**Why it happens:** iOS automatically updates preferredCompactColumn when popping NavigationStack. Conflicting updates cause inconsistent state.
**How to avoid:** Don't programmatically change preferredCompactColumn while NavigationStack has pushed views. Use selection-based navigation instead of stack when possible.
**Warning signs:** Navigation freezes after sidebar toggle while viewing a detail.
**Workaround if needed:** Force re-render with `.id(UUID())` on NavigationSplitView (causes flicker but recovers).

### Pitfall 4: Small iPhone Support Issues
**What goes wrong:** NavigationSplitView behaves erratically on iPhone SE, freezing or showing wrong column.
**Why it happens:** NavigationSplitView optimized for larger screens; some code paths less tested on SE.
**How to avoid:** Test on iPhone SE early and often. Use simpler navigation patterns if issues emerge.
**Warning signs:** Detail view freezes, wrong column shows after launch.
**Test immediately:** Run on iPhone SE simulator, verify sidebar can be accessed.

### Pitfall 5: Toolbar Hidden Hides Sidebar Button
**What goes wrong:** Using `.toolbar(.hidden, for: .navigationBar)` on detail view hides the sidebar toggle button.
**Why it happens:** Sidebar toggle is a toolbar item; hiding toolbar hides it too.
**How to avoid:** If hiding toolbar, provide alternate way to show sidebar. Or use `.toolbarBackground(.hidden)` to hide background but keep items.
**Warning signs:** On iPhone, no way to get back to sidebar after entering detail.

### Pitfall 6: Conditional Views Not Updating
**What goes wrong:** Detail view content doesn't update when sidebar selection changes.
**Why it happens:** SwiftUI optimization skips re-render if view identity appears unchanged.
**How to avoid:** Wrap detail content in ZStack or use `.id(selectedSection)` modifier.
**Warning signs:** Tapping different sidebar items shows stale detail content.

## Code Examples

Verified patterns from official and authoritative sources:

### Complete RootNavigationView Implementation
```swift
// Source: Composite from Apple TN3154, swiftwithmajid.com, fatbobman.com
import SwiftUI

struct RootNavigationView: View {
    @State private var navigationModel = NavigationModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationSplitView(
            columnVisibility: $navigationModel.columnVisibility,
            preferredCompactColumn: .constant(.detail)
        ) {
            sidebar
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        List(selection: $navigationModel.selectedSection) {
            Section("Library") {
                Label("All Videos", systemImage: SidebarSection.library.icon)
                    .tag(SidebarSection.library)
            }

            Section("Filters") {
                Label("Types", systemImage: SidebarSection.types.icon)
                    .tag(SidebarSection.types)
                Label("Tags", systemImage: SidebarSection.tags.icon)
                    .tag(SidebarSection.tags)
            }

            Section("Organization") {
                Label("Playbooks", systemImage: SidebarSection.playbooks.icon)
                    .tag(SidebarSection.playbooks)
            }

            Section {
                Label("Trash", systemImage: SidebarSection.trash.icon)
                    .tag(SidebarSection.trash)
            }
        }
        .navigationTitle("Scrollsmith")
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailContent: some View {
        NavigationStack(path: navigationModel.currentPath) {
            // ZStack prevents conditional view update issues
            ZStack {
                switch navigationModel.selectedSection {
                case .library:
                    VideoGridView()
                        .navigationTitle("Library")
                case .types:
                    Text("Types Filter - Coming in Phase 15")
                        .navigationTitle("Types")
                case .playbooks:
                    PlaybookListView()
                        .navigationTitle("Playbooks")
                case .tags:
                    Text("Tags - Coming in Phase 15")
                        .navigationTitle("Tags")
                case .trash:
                    Text("Trash - Coming in Phase 15")
                        .navigationTitle("Trash")
                case .none:
                    ContentUnavailableView(
                        "Select a Section",
                        systemImage: "sidebar.left",
                        description: Text("Choose from the sidebar")
                    )
                }
            }
            .navigationDestination(for: VideoDTO.self) { video in
                SummaryDisplayView(video: video)
            }
            .navigationDestination(for: PlaybookDTO.self) { playbook in
                PlaybookDetailView(playbook: playbook)
            }
        }
    }
}
```

### SceneStorage State Persistence
```swift
// Source: nilcoalescing.com, Apple documentation
@Observable
final class NavigationModel {
    // Use RawRepresentable enum for SceneStorage compatibility
    var selectedSection: SidebarSection? = .library {
        didSet {
            // Sync to UserDefaults for cross-launch persistence
            UserDefaults.standard.set(selectedSection?.rawValue, forKey: "selectedSection")
        }
    }

    init() {
        // Restore selection on launch
        if let rawValue = UserDefaults.standard.string(forKey: "selectedSection"),
           let section = SidebarSection(rawValue: rawValue) {
            self.selectedSection = section
        }
    }
}

// Alternative: Use SceneStorage in View for simpler cases
struct RootNavigationView: View {
    @SceneStorage("selectedSection") private var selectedSectionRaw: String = "Library"

    private var selectedSection: Binding<SidebarSection?> {
        Binding(
            get: { SidebarSection(rawValue: selectedSectionRaw) },
            set: { selectedSectionRaw = $0?.rawValue ?? "Library" }
        )
    }
}
```

### Column Visibility Toggle
```swift
// Source: useyourloaf.com, swiftwithmajid.com
struct DetailView: View {
    @Binding var columnVisibility: NavigationSplitViewVisibility

    var body: some View {
        VStack {
            // Content
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation {
                        columnVisibility = columnVisibility == .detailOnly
                            ? .all
                            : .detailOnly
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NavigationView | NavigationSplitView | iOS 16 (2022) | NavigationView deprecated; NavigationSplitView is official |
| @StateObject + ObservableObject | @Observable | iOS 17 (2023) | Simpler, more efficient observation |
| NavigationLink(destination:) | NavigationLink(value:) + .navigationDestination | iOS 16 (2022) | Type-safe, programmatic navigation |
| isActive binding | NavigationPath | iOS 16 (2022) | Type-erased path; handles complex navigation |

**Deprecated/outdated:**
- **NavigationView:** Officially deprecated iOS 16+. Use NavigationSplitView for multi-column, NavigationStack for single-column.
- **isActive/selection bindings on NavigationLink:** Use value-based NavigationLink with .navigationDestination modifier.
- **@Published in ObservableObject:** Still works but @Observable is preferred for new iOS 17+ code.

## Open Questions

Things that couldn't be fully resolved:

1. **CaptureView Presentation**
   - What we know: CaptureView is currently a tab. Sidebar pattern typically uses modal for creation actions.
   - What's unclear: Should CaptureView be a sidebar item or fullScreenCover triggered from toolbar?
   - Recommendation: Present as fullScreenCover from floating action button or toolbar. Keeps sidebar for navigation, modal for actions. Decide during implementation.

2. **HabitListView Placement**
   - What we know: HabitListView is currently a tab. Could be sidebar section or modal.
   - What's unclear: Is habit tracking "navigation" or "action"? Do users browse habits or just complete them?
   - Recommendation: Start as sidebar section. If user research shows it's an action, move to modal. Low-cost to change.

3. **Navigation Path Persistence Across App Kills**
   - What we know: SceneStorage persists across backgrounding. NavigationPath is Codable.
   - What's unclear: Does persisting NavigationPath across app kills cause issues with stale video references?
   - Recommendation: Persist sidebar selection (simple string), but reset NavigationPath on cold launch. Prevents stale data issues.

4. **iPad Stage Manager Multi-Window**
   - What we know: SceneStorage provides per-scene persistence. NavigationSplitView works in multi-window.
   - What's unclear: Are there edge cases with multiple Scrollsmith windows open simultaneously?
   - Recommendation: Test with Stage Manager during Phase 13 implementation. Low risk but worth validating.

## Sources

### Primary (HIGH confidence)
- [NavigationSplitView - Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview) - Core API reference
- [TN3154: Adopting SwiftUI NavigationSplitView - Apple](https://developer.apple.com/documentation/technotes/tn3154-adopting-swiftui-navigation-split-view) - Official adoption guide
- [Mastering NavigationSplitView in SwiftUI - Swift with Majid](https://swiftwithmajid.com/2022/10/18/mastering-navigationsplitview-in-swiftui/) - Complete examples
- [Deep Dive into Modern SwiftUI Navigation - Fatbobman](https://fatbobman.com/en/posts/new_navigator_of_swiftui_4/) - State management patterns
- [NavigationSplitView's Hidden Trap - The Empathic Dev](https://theempathicdev.de/blog/advanced-navigation-split-view-bugs) - Critical bug documentation

### Secondary (MEDIUM confidence)
- [SwiftUI Split View Configuration - Use Your Loaf](https://useyourloaf.com/blog/swiftui-split-view-configuration/) - Style and width configuration
- [Exploring the Navigation Split View - Create with Swift](https://www.createwithswift.com/exploring-the-navigationsplitview/) - Comprehensive tutorial
- [How to control NavigationSplitView column in compact layouts - Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-control-which-navigationsplitview-column-is-shown-in-compact-layouts) - iPhone handling
- [State restoration with SceneStorage - nilcoalescing](https://nilcoalescing.com/blog/UsingSceneStorageForStateRestorationInSwiftUIApps/) - Persistence patterns

### Tertiary (LOW confidence - needs validation)
- [Apple Developer Forums - Navigation state preservation](https://developer.apple.com/forums/thread/756897) - Community reports on iPad rotation issues
- [GitHub Gist - NavigationSplitView with global navigation](https://gist.github.com/nkalvi/4cdc746ab92b5da664621d61ac7690e9) - Community example following Apple patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All native SwiftUI iOS 17+ components with official documentation
- Architecture: HIGH - Patterns verified across Apple docs, WWDC, and authoritative community sources
- Pitfalls: HIGH - Well-documented in Apple forums and community; multiple sources confirm same issues

**Research date:** 2026-01-29
**Valid until:** ~90 days (NavigationSplitView API stable since iOS 16, patterns unlikely to change)
