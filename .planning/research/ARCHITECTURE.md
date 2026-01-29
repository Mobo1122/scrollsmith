# Architecture: Readwise Reader-Inspired Sidebar + Feed Integration

**Domain:** SwiftUI Navigation Architecture for Video Library App
**Researched:** 2026-01-29
**Overall Confidence:** HIGH (Apple documentation + established patterns)

## Executive Summary

The Readwise Reader-inspired UI requires migrating from TabView to NavigationSplitView, SwiftUI's modern three-column navigation component. This architectural shift transforms Scrollsmith from tab-based navigation to a sidebar + feed layout that adapts intelligently between iPhone (stack-based) and iPad (multi-column).

**Key insight:** NavigationSplitView provides automatic platform adaptation but requires careful state management, especially for preserving navigation paths when switching between sidebar items. The existing Views/ structure can be preserved with minimal changes—the primary work is creating new container views and feed components.

**Critical for roadmap:** This is a navigation restructuring, not a full rewrite. Build order should prioritize the new navigation shell first, then progressively migrate existing views into it, minimizing risk of breaking working features.

## Recommended Architecture

### High-Level Structure

```
NavigationSplitView (replaces MainTabView)
├── Sidebar (left column - iPad visible, iPhone hidden/overlay)
│   ├── Library section
│   │   └── All Videos (feed)
│   ├── Types section
│   │   ├── YouTube
│   │   └── Camera Roll
│   ├── Playbooks section (dynamic list)
│   ├── Tags section (future)
│   └── Trash (future)
│
└── Detail (right column - feed/content)
    └── NavigationStack (for drill-down)
        ├── VideoFeedView (new - replaces VideoGridView for "All Videos")
        ├── VideoGridView (existing - reused for filtered views)
        └── SummaryDisplayView (existing - no changes)
```

### Component Boundaries

| Component | Responsibility | Communicates With | File Location |
|-----------|---------------|-------------------|---------------|
| **RootNavigationView** | NavigationSplitView container, manages columnVisibility | SidebarView, DetailRouter | `Views/Navigation/RootNavigationView.swift` (NEW) |
| **SidebarView** | Sidebar content with Library/Types/Playbooks sections | PlaybookViewModel, selection state | `Views/Navigation/SidebarView.swift` (NEW) |
| **DetailRouter** | Routes sidebar selection to appropriate detail view | VideoFeedView, VideoGridView, existing views | `Views/Navigation/DetailRouter.swift` (NEW) |
| **VideoFeedView** | Inbox-style feed with video cards (List-based) | VideoFeedViewModel, VideoCardView | `Views/Videos/VideoFeedView.swift` (NEW) |
| **VideoCardView** | Individual video card in feed (thumbnail, metadata) | VideoDTO | `Views/Videos/VideoCardView.swift` (NEW) |
| **VideoGridView** | Existing grid view for filtered content | Unchanged | `Views/Videos/VideoGridView.swift` (REUSE) |
| **CaptureView** | Capture interface (modal presentation) | Unchanged | `Views/Capture/CaptureView.swift` (REUSE) |
| **SettingsView** | Settings interface (sidebar item or modal) | Unchanged | `Views/Settings/SettingsView.swift` (REUSE) |
| **HabitListView** | Habits interface (sidebar item or modal) | Unchanged | `Views/Habits/HabitListView.swift` (REUSE) |

### Data Flow

```
User taps sidebar item
    ↓
RootNavigationView updates @State selection
    ↓
DetailRouter observes selection change
    ↓
DetailRouter presents appropriate view:
    - "all-videos" → VideoFeedView (feed layout)
    - playbook-{id} → VideoGridView(playbookId: id) (grid layout)
    - "youtube" → VideoGridView(sourceType: .youtube) (grid layout)
    - "settings" → SettingsView
    ↓
User taps video in feed/grid
    ↓
NavigationStack pushes SummaryDisplayView
    ↓
NavigationStack state preserved when returning to feed
```

## Patterns to Follow

### Pattern 1: NavigationSplitView with State Binding

**What:** Modern three-column navigation that adapts to device size
**When:** Primary app navigation, replacing TabView
**Why:** Apple-recommended pattern for sidebar UIs, automatic iPhone/iPad adaptation

**Example:**
```swift
struct RootNavigationView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selectedItem: SidebarItem? = .allVideos

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SidebarView(selection: $selectedItem)
                .navigationTitle("Library")
        } detail: {
            // Detail with NavigationStack for drill-down
            NavigationStack {
                DetailRouter(selection: selectedItem)
            }
        }
        .navigationSplitViewStyle(.balanced) // Side-by-side on iPad
    }
}
```

**Key considerations:**
- `columnVisibility` controls sidebar visibility (automatic, all, detailOnly)
- `.automatic` shows sidebar on iPad, hides on iPhone (accessible via button)
- `.balanced` keeps sidebar visible in both orientations on iPad
- Selection state must be `@State` or `@Binding` for reactivity

**Sources:**
- [Mastering NavigationSplitView in SwiftUI](https://swiftwithmajid.com/2022/10/18/mastering-navigationsplitview-in-swiftui/)
- [SwiftUI Split View Configuration](https://useyourloaf.com/blog/swiftui-split-view-configuration/)

### Pattern 2: NavigationStack in Detail Column

**What:** Wrap detail content in NavigationStack for drill-down navigation
**When:** User needs to navigate deeper (feed → video detail → habit creation)
**Why:** Preserves navigation state, provides back button, enables toolbar customization

**Example:**
```swift
NavigationSplitView {
    SidebarView(selection: $selectedItem)
} detail: {
    NavigationStack {  // ← Critical for navigation paths
        DetailRouter(selection: selectedItem)
            .toolbar {
                // Detail-specific toolbar items
            }
    }
}
```

**Anti-pattern to avoid:**
```swift
// DON'T wrap sidebar in NavigationStack
NavigationSplitView {
    NavigationStack {  // ← Causes navigation issues
        SidebarView()
    }
} detail: { ... }
```

**Sources:**
- [Deep Dive into Modern SwiftUI Navigation](https://fatbobman.com/en/posts/new_navigator_of_swiftui_4/)
- Apple Developer Forums discussions on NavigationStack placement

### Pattern 3: Enum-Based Sidebar Selection

**What:** Type-safe sidebar routing with enum identifiers
**When:** Managing multiple sidebar items and routing logic
**Why:** Compile-time safety, exhaustive switch handling, clear intent

**Example:**
```swift
enum SidebarItem: Hashable, Identifiable {
    case allVideos
    case youtube
    case cameraRoll
    case playbook(UUID)
    case uncategorized
    case settings
    case habits

    var id: String {
        switch self {
        case .allVideos: return "all-videos"
        case .youtube: return "youtube"
        case .cameraRoll: return "camera-roll"
        case .playbook(let id): return "playbook-\(id.uuidString)"
        case .uncategorized: return "uncategorized"
        case .settings: return "settings"
        case .habits: return "habits"
        }
    }
}

struct DetailRouter: View {
    let selection: SidebarItem?

    var body: some View {
        Group {
            switch selection {
            case .allVideos:
                VideoFeedView()
            case .youtube:
                VideoGridView(sourceType: .youtube)
            case .cameraRoll:
                VideoGridView(sourceType: .cameraRoll)
            case .playbook(let id):
                VideoGridView(playbookId: id)
            case .uncategorized:
                VideoGridView(playbookId: nil, showUncategorized: true)
            case .settings:
                SettingsView()
            case .habits:
                HabitListView()
            case .none:
                ContentUnavailableView(
                    "Select an item",
                    systemImage: "sidebar.left"
                )
            }
        }
    }
}
```

**Sources:**
- [Exploring the Navigation Split View](https://www.createwithswift.com/exploring-the-navigationsplitview/)
- Community patterns from Swift forums

### Pattern 4: Feed with List (not LazyVStack)

**What:** Use `List { ForEach(videos) { ... } }` for video feed
**When:** Building infinite-scrolling feed with 10+ items
**Why:** Better performance, built-in cell recycling, scroll performance optimization

**Example:**
```swift
struct VideoFeedView: View {
    @State private var viewModel = VideoFeedViewModel()

    var body: some View {
        List {
            ForEach(viewModel.videos) { video in
                NavigationLink(value: video) {
                    VideoCardView(video: video)
                }
                .onAppear {
                    // Pagination trigger
                    if video == viewModel.videos.last {
                        Task { await viewModel.loadMore() }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: VideoDTO.self) { video in
            SummaryDisplayView(video: video)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
```

**Performance considerations (iOS 18+):**
- List has "pretty good performance, memory use, and cell recycling"
- Prefer `.listStyle(.plain)` for feed-like appearance
- Use `.onAppear` on last item for pagination (common pattern)
- Avoid `GeometryReader` in rows (causes layout recalculation)
- Cache images aggressively (consider AsyncImage alternatives like Kingfisher)

**Anti-patterns to avoid:**
- Using LazyVStack for large datasets (no cell recycling)
- Eager image loading in AsyncImage (loads offscreen images)
- GeometryReader per row
- Nested Lists

**Sources:**
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)
- [The Next Page: Building Infinite Scroll with SwiftUI](https://medium.com/whatnot-engineering/the-next-page-8950875d927a)

### Pattern 5: Modal Presentation for Capture

**What:** Present CaptureView as fullScreenCover instead of sidebar/tab item
**When:** User-initiated action (FAB button or toolbar item)
**Why:** Capture is a distinct flow, not a browsing destination; modal keeps context clear

**Example:**
```swift
struct RootNavigationView: View {
    @State private var showCapture = false

    var body: some View {
        NavigationSplitView { ... }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCapture = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCapture) {
                CaptureView()
            }
    }
}
```

**Alternative:** Floating Action Button (FAB) overlay for Readwise-style UX:
```swift
.overlay(alignment: .bottomTrailing) {
    if selectedItem != .settings {  // Hide on settings
        Button {
            showCapture = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, Theme.accent)
        }
        .padding()
    }
}
```

### Pattern 6: State Preservation with Navigation Path Dictionary

**What:** Maintain separate navigation paths for each sidebar item
**When:** User navigates deep into one section, switches sidebar items, then returns
**Why:** Preserves user's place in each section (UX expectation from Readwise Reader)

**Current limitation:** NavigationSplitView doesn't automatically preserve navigation paths when switching detail views. This is a known SwiftUI issue as of iOS 17-18.

**Workaround pattern:**
```swift
struct RootNavigationView: View {
    @State private var selectedItem: SidebarItem? = .allVideos
    @State private var navigationPaths: [String: NavigationPath] = [:]

    private var currentPath: Binding<NavigationPath> {
        Binding(
            get: { navigationPaths[selectedItem?.id ?? ""] ?? NavigationPath() },
            set: { navigationPaths[selectedItem?.id ?? ""] = $0 }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            NavigationStack(path: currentPath) {
                DetailRouter(selection: selectedItem)
            }
        }
    }
}
```

**Recommendation for v1.1:** Skip this complexity initially. Implement only if user testing shows confusion when navigation paths reset. Most users won't notice for shallow hierarchies (feed → video detail).

**Sources:**
- [NavigationSplitView resetting when switching](https://developer.apple.com/forums/thread/733472)
- [Persist navigation paths in NavigationSplitView](https://developer.apple.com/forums/thread/741538)

## Anti-Patterns to Avoid

### Anti-Pattern 1: TabView Inside NavigationSplitView

**What goes wrong:** Mixing tab-based navigation with sidebar navigation creates confusing UX
**Why it happens:** Attempting to preserve old TabView while adding sidebar
**Consequences:**
- Unclear navigation hierarchy (two competing navigation models)
- iPad shows both tabs and sidebar (redundant)
- Breaks Apple HIG for split view apps

**Prevention:**
- Choose one navigation model: sidebar (NavigationSplitView) OR tabs (TabView)
- For Readwise-style UI, fully commit to sidebar navigation
- Move tab content (Habits, Settings) into sidebar or toolbar actions

**Sources:**
- [Hacking with Swift forum discussion](https://www.hackingwithswift.com/forums/swiftui/how-to-use-different-toolbars-for-each-tab-view-inside-a-navigationsplitview/21148)
- Apple HIG guidelines on navigation patterns

### Anti-Pattern 2: NavigationStack Wrapping Sidebar

**What goes wrong:** Wrapping sidebar content in NavigationStack causes navigation issues
**Why it happens:** Misunderstanding of where NavigationStack belongs
**Consequences:**
- Sidebar selections don't properly drive detail view changes
- Navigation paths interfere with split view selection state
- Unexpected navigation behavior on iPad

**Prevention:**
- NavigationStack goes in **detail column only**
- Sidebar contains selection UI (List, buttons), not navigation destinations
- Use NavigationLink in detail column, not sidebar

**Correct:**
```swift
NavigationSplitView {
    List(selection: $selectedItem) { ... }  // No NavigationStack
} detail: {
    NavigationStack { ... }  // NavigationStack here
}
```

**Sources:**
- [Deep Dive into Modern SwiftUI Navigation](https://fatbobman.com/en/posts/new_navigator_of_swiftui_4/)

### Anti-Pattern 3: LazyVStack for Feed (at scale)

**What goes wrong:** LazyVStack loads all views as user scrolls, no cell recycling
**Why it happens:** LazyVStack feels more "custom" than List
**Consequences:**
- Memory grows unbounded as user scrolls
- Performance degrades with 50+ items
- Frame rate drops below 60fps on scroll

**Prevention:**
- Use `List` for feeds with 10+ items
- Reserve LazyVStack for fixed-size content (e.g., 5-item grid)
- Test with 100+ items to verify performance

**Detection:**
- Instruments showing memory growth during scroll
- Frame rate below 60fps in Xcode performance monitor

**Sources:**
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)

### Anti-Pattern 4: Deep View Hierarchies in Feed Rows

**What goes wrong:** Nested VStack/HStack/ZStack in feed rows cause layout thrashing
**Why it happens:** Building complex card designs without consideration for recomputation
**Consequences:**
- Scroll stuttering
- High CPU usage during scroll
- Poor battery life

**Prevention:**
- Keep VideoCardView shallow (max 3 levels of nesting)
- Extract subviews if nesting exceeds 3 levels
- Make rows conform to `Equatable` to prevent unnecessary recomputation
- Avoid dynamic GeometryReader in rows

**Example of prevention:**
```swift
// Good: Shallow, Equatable
struct VideoCardView: View, Equatable {
    let video: VideoDTO

    static func == (lhs: VideoCardView, rhs: VideoCardView) -> Bool {
        lhs.video.id == rhs.video.id
    }

    var body: some View {
        HStack(spacing: 12) {  // Level 1
            AsyncImage(url: video.thumbnailURL)
                .frame(width: 120, height: 68)  // Level 2

            VStack(alignment: .leading) {  // Level 2
                Text(video.title)
                Text(video.creator)
            }
        }
        .padding()  // Level 2
    }
}
```

**Sources:**
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)

## Migration Strategy: Minimize Breaking Changes

### Phase 1: New Navigation Shell (High Priority)

**Goal:** Replace MainTabView with NavigationSplitView without breaking existing views

**New files to create:**
1. `Views/Navigation/RootNavigationView.swift` - NavigationSplitView container
2. `Views/Navigation/SidebarView.swift` - Sidebar content
3. `Views/Navigation/DetailRouter.swift` - Routes selection to detail views
4. `ViewModels/NavigationViewModel.swift` (optional) - Shared navigation state

**Modified files:**
1. `ContentView.swift` - Replace `MainTabView()` with `RootNavigationView()`
2. `MainTabView.swift` - Mark deprecated, remove after migration complete

**No changes to:**
- All Views/ subdirectories (Auth, Capture, Habits, Playbooks, Summary, Videos, Settings)
- All ViewModels (except new NavigationViewModel if created)
- All Services

**Build order:**
1. Create SidebarItem enum in new file
2. Create SidebarView with hardcoded items (Library, Settings only)
3. Create DetailRouter with .allVideos → PlaybookListView (temporary)
4. Create RootNavigationView connecting sidebar + detail
5. Update ContentView to use RootNavigationView
6. **Verify:** App launches, sidebar works, Settings view accessible
7. **Test on iPad:** Sidebar visible, detail column functional

**Risk:** LOW - Existing views are untouched, only navigation container changes

---

### Phase 2: Video Feed Implementation (Medium Priority)

**Goal:** Create inbox-style video feed with cards

**New files to create:**
1. `Views/Videos/VideoFeedView.swift` - List-based feed
2. `Views/Videos/VideoCardView.swift` - Individual card component
3. `ViewModels/VideoFeedViewModel.swift` - Feed data + pagination

**Modified files:**
1. `DetailRouter.swift` - Route .allVideos to VideoFeedView (instead of PlaybookListView)
2. `SidebarView.swift` - Add "All Videos" to Library section

**No changes to:**
- VideoGridView (preserved for filtered views)
- SummaryDisplayView (reused via NavigationLink)
- PlaybookListView (moves to sidebar item, not home screen)

**Build order:**
1. Create VideoCardView with thumbnail, title, metadata (static preview data)
2. Create VideoFeedViewModel with getVideos() API call
3. Create VideoFeedView with List + VideoCardView
4. Add NavigationLink to SummaryDisplayView
5. Update DetailRouter to show VideoFeedView for .allVideos
6. **Verify:** Feed loads, cards display, navigation to summary works
7. **Test pagination:** Scroll to bottom, verify loadMore() triggers

**Risk:** MEDIUM - New view with API dependencies, pagination complexity

---

### Phase 3: Sidebar Population (Medium Priority)

**Goal:** Add Types, Playbooks, dynamic items to sidebar

**Modified files:**
1. `SidebarView.swift` - Add Types section, Playbooks section
2. `DetailRouter.swift` - Add cases for .youtube, .cameraRoll, .playbook(id)

**Reused views:**
- VideoGridView with sourceType parameter (new)
- VideoGridView with playbookId parameter (existing)
- PlaybookDetailView (existing, accessed via sidebar navigation)

**Build order:**
1. Add Types section to SidebarView (YouTube, Camera Roll)
2. Update DetailRouter for .youtube, .cameraRoll → VideoGridView
3. Add Playbooks section with ForEach(playbooks)
4. Update DetailRouter for .playbook(id) → VideoGridView
5. **Verify:** Filtering works, grid view displays correctly
6. **Test:** Switch between sidebar items, verify content updates

**Risk:** LOW - Reusing existing VideoGridView, minimal new code

---

### Phase 4: Modal Actions (Low Priority)

**Goal:** Move Capture and Habits to modal presentation or toolbar

**Modified files:**
1. `RootNavigationView.swift` - Add .fullScreenCover for Capture
2. `SidebarView.swift` - Add Habits as sidebar item OR
3. `RootNavigationView.swift` - Add .sheet for Habits

**Build order:**
1. Add toolbar button (FAB or toolbar item) for Capture
2. Add .fullScreenCover(isPresented: $showCapture) { CaptureView() }
3. Decide: Habits in sidebar or toolbar?
   - Sidebar: Add to SidebarView, route in DetailRouter
   - Toolbar: Add .sheet(isPresented: $showHabits) { HabitListView() }
4. Remove MainTabView.swift (migration complete)
5. **Verify:** Capture modal works, Habits accessible
6. **Test:** Upload flow, habit creation flow

**Risk:** LOW - Modal presentation is well-tested pattern

---

### Phase 5: Polish & iPad Optimization (Low Priority)

**Goal:** Refine iPad experience, sidebar behavior, column visibility

**Modified files:**
1. `RootNavigationView.swift` - Add .navigationSplitViewStyle(.balanced)
2. `SidebarView.swift` - Adjust sidebar width, styling
3. `VideoFeedView.swift` - Optimize for wide screen (iPad landscape)

**Build order:**
1. Test on iPad Pro simulator (landscape + portrait)
2. Add .navigationSplitViewStyle(.balanced) for side-by-side
3. Adjust VideoCardView layout for iPad (wider cards?)
4. Consider two-column grid on iPad landscape
5. **Verify:** Looks good on all iPad sizes
6. **Test:** Rotation, multitasking, sidebar persistence

**Risk:** LOW - Polish phase, no functional changes

## iPhone vs iPad Behavior

### iPhone (Compact Size Class)

**Automatic behavior:**
- NavigationSplitView collapses to stack-style navigation
- Sidebar hidden by default, accessible via toolbar button
- Detail view takes full screen
- Back button automatically appears when sidebar visible
- **No code changes required** for this adaptation

**User flow:**
1. App opens to detail view (feed)
2. Tap sidebar button in toolbar → sidebar slides in from left
3. Select item → sidebar slides out, detail view updates
4. Deep navigation (feed → video) uses standard push animation

**Visual:**
```
[Sidebar Button] Feed Title
┌────────────────────────┐
│                        │
│   Video Feed           │
│   ┌──────────┐         │
│   │  Card    │         │
│   └──────────┘         │
│   ┌──────────┐         │
│   │  Card    │         │
│   └──────────┘         │
│                        │
└────────────────────────┘
```

### iPad (Regular Size Class)

**Automatic behavior:**
- NavigationSplitView shows two columns side-by-side (with .balanced style)
- Sidebar visible by default (portrait: overlay, landscape: side-by-side)
- Detail column shows content
- Sidebar toggle button available in toolbar

**User flow:**
1. App opens with sidebar visible (landscape) or hidden (portrait)
2. Select sidebar item → detail view updates in place
3. Deep navigation (feed → video) pushes in detail column only
4. Sidebar stays visible during drill-down (landscape)

**Visual (Landscape):**
```
┌────────────┬──────────────────────┐
│  Library   │  Feed Title          │
│  • All Vid │  ┌──────────┐        │
│  Types     │  │  Card    │        │
│  • YouTube │  └──────────┘        │
│  • Camera  │  ┌──────────┐        │
│  Playbooks │  │  Card    │        │
│  • Learn   │  └──────────┘        │
│  • Cooking │                      │
└────────────┴──────────────────────┘
```

**Key differences:**
- Sidebar width: ~320pt on iPad vs full screen on iPhone
- Column visibility: persistent vs hidden
- Interaction: select vs tap-and-dismiss

## File Structure Changes

### New Files (Create)

```
ios/Scrollsmith/
├── Views/
│   ├── Navigation/           (NEW FOLDER)
│   │   ├── RootNavigationView.swift
│   │   ├── SidebarView.swift
│   │   └── DetailRouter.swift
│   └── Videos/
│       ├── VideoFeedView.swift     (NEW)
│       └── VideoCardView.swift     (NEW)
└── ViewModels/
    ├── NavigationViewModel.swift   (NEW, optional)
    └── VideoFeedViewModel.swift    (NEW)
```

### Modified Files

```
ios/Scrollsmith/
├── ContentView.swift           (Change: MainTabView() → RootNavigationView())
└── Views/
    ├── MainTabView.swift      (Deprecated after migration complete)
    └── Videos/
        └── VideoGridView.swift (Minor: add sourceType filter parameter)
```

### Unchanged Files (Reuse As-Is)

```
ios/Scrollsmith/
├── Views/
│   ├── Auth/             (All files unchanged)
│   ├── Capture/          (All files unchanged)
│   ├── Habits/           (All files unchanged)
│   ├── Playbooks/        (All files unchanged - reused in sidebar)
│   ├── Settings/         (All files unchanged)
│   ├── Summary/          (All files unchanged)
│   └── Videos/
│       └── VideoGridView.swift  (Reused for filtered views)
└── ViewModels/           (Most unchanged - reused)
```

## Build Order Summary (Risk-Minimized)

| Phase | Priority | Risk | Blocks | Files Changed | Can Ship? |
|-------|----------|------|--------|---------------|-----------|
| 1. Navigation Shell | HIGH | LOW | Everything | 4 new, 1 modified | No (incomplete) |
| 2. Video Feed | HIGH | MEDIUM | Feed UX | 3 new | Yes (minimal viable) |
| 3. Sidebar Population | MEDIUM | LOW | Full sidebar UX | 2 modified | Yes (feature-complete) |
| 4. Modal Actions | MEDIUM | LOW | None | 1-2 modified | Yes (polish) |
| 5. iPad Polish | LOW | LOW | None | 2-3 modified | Yes (optimized) |

**Recommended first shipment:** After Phase 3 (functional parity with current app + new feed UI)

**Recommended MVP:** After Phase 2 (new feed works, sidebar partially functional)

## Confidence Assessment

| Area | Confidence | Source |
|------|------------|--------|
| NavigationSplitView API | HIGH | Apple documentation, established since iOS 16 |
| iPhone/iPad adaptation | HIGH | Automatic behavior, well-documented |
| Migration strategy | HIGH | Preserves existing views, minimal changes |
| Feed performance (List) | MEDIUM-HIGH | Community best practices, recent (2025-2026) articles |
| State preservation | MEDIUM | Known SwiftUI limitation, workaround available |
| Build order feasibility | HIGH | Phased approach with clear dependencies |

## Known Limitations & Gaps

### NavigationPath State Preservation

**Issue:** NavigationSplitView doesn't automatically preserve navigation paths when switching between sidebar items. User navigates deep into "Playbooks" (Playbook → Video → Habit), switches to "All Videos", then back to "Playbooks" → navigation path resets to root.

**Impact:** Minor UX friction for power users navigating deeply

**Mitigation:** Workaround available (path dictionary pattern), but adds complexity. Recommend deferring unless user testing shows this is a pain point.

**Confidence in workaround:** MEDIUM (reported working in forums, but not officially documented)

### Feed Pagination Best Practices

**Issue:** Articles show different approaches to infinite scroll (.onAppear, .task, custom triggers). No single authoritative pattern.

**Impact:** May need iteration to find performant approach

**Mitigation:** Start with .onAppear on last item (most common pattern), measure performance, iterate if needed.

**Confidence:** MEDIUM (pattern is common but implementation details matter)

### AsyncImage Performance at Scale

**Issue:** AsyncImage eagerly loads images for offscreen cells, wasting bandwidth and memory

**Impact:** Feed performance degrades with 50+ videos

**Mitigation:** Consider third-party library (Kingfisher, Nuke) for image caching if performance issues emerge

**Confidence:** HIGH that issue exists, MEDIUM on when it becomes critical (depends on user behavior)

## Sources

### High Confidence (Official/Primary)

- [Apple Developer: NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Apple Developer: Migrating to new navigation types](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)
- [Apple Developer: TN3154 - Adopting SwiftUI navigation split view](https://developer.apple.com/documentation/technotes/tn3154-adopting-swiftui-navigation-split-view)
- [Mastering NavigationSplitView in SwiftUI](https://swiftwithmajid.com/2022/10/18/mastering-navigationsplitview-in-swiftui/) - Swift with Majid (established SwiftUI expert)
- [Deep Dive into Modern SwiftUI Navigation](https://fatbobman.com/en/posts/new_navigator_of_swiftui_4/) - Fatbobman (SwiftUI authority)

### Medium Confidence (Community Best Practices)

- [Exploring the Navigation Split View](https://www.createwithswift.com/exploring-the-navigationsplitview/)
- [SwiftUI Split View Configuration](https://useyourloaf.com/blog/swiftui-split-view-configuration/)
- [Getting started with the SwiftUI NavigationSplitView](https://danielsaidi.com/blog/2022/08/08/getting-started-with-the-SwiftUI-navigation-split-view)
- [Programmatically hide and show sidebar in split view](https://nilcoalescing.com/blog/ProgrammaticallyHideAndShowSidebarInSplitView/)
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps) - Performance analysis (2025)
- [The Next Page: Building Infinite Scroll with SwiftUI](https://medium.com/whatnot-engineering/the-next-page-8950875d927a) - Whatnot Engineering

### Readwise Reader Research

- [Readwise Reader Navigation Docs](https://docs.readwise.io/reader/docs/faqs/navigation)
- [Readwise & Reader Changelog](https://docs.readwise.io/changelog) - Sticky tablet sidebars feature (2026)
- [The Next Chapter of Reader: Public Beta](https://blog.readwise.io/the-next-chapter-of-reader-public-beta/)

### State Preservation Discussions

- [Apple Developer Forums: Preserving navigation state in NavigationSplitView detail](https://developer.apple.com/forums/thread/756897)
- [Apple Developer Forums: Persist navigation paths in NavigationSplitView](https://developer.apple.com/forums/thread/741538)
- [Hacking with Swift Forums: NavigationStack path is cleared when switching tabs](https://www.hackingwithswift.com/forums/swiftui/navigationstack-path-is-cleared-when-switching-tabs-in-navigationsplitview/30157)

---

**Final Recommendation for Roadmap:**

Structure phases to build navigation shell first (Phase 1), then video feed (Phase 2), then populate sidebar (Phase 3). This order minimizes risk—each phase is independently testable and shippable. Existing views remain untouched until Phase 4-5, reducing chance of regression. iPad-specific polish can be deferred to final phase without blocking core functionality.
