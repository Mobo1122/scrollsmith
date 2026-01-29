# Domain Pitfalls: SwiftUI UI Redesign (Tab to Sidebar Navigation)

**Domain:** SwiftUI major UI redesign - Tab-based to Sidebar navigation with feed/list layouts
**Researched:** 2026-01-29
**Confidence:** HIGH (SwiftUI-specific), MEDIUM (Scrollsmith-specific integration)

**Context:** Scrollsmith v1.1 is transforming from tab-based navigation (TabView) to sidebar + feed layout (Readwise Reader style). Key changes include:
- Tab bar → NavigationSplitView with sidebar
- Grid view → Feed/list view with cards
- Adding thumbnails, creator credits, embedded YouTube
- Fixing existing bugs (button overlap, non-functional panels)

---

## Critical Pitfalls

Mistakes that cause rewrites, major refactoring, or severe user experience degradation.

### Pitfall 1: NavigationSplitView Selection Binding Forgotten

**What goes wrong:**
The sidebar displays correctly, but tapping items does nothing. Navigation appears completely broken despite selection state being tracked in @State. This is one of the most subtle and frustrating NavigationSplitView requirements.

**Why it happens:**
Developers track the current sidebar selection as a @State property but forget to bind the selection to the view hierarchy. NavigationSplitView needs explicit selection binding to know about the currently selected screen.

**Consequences:**
- Sidebar navigation completely non-functional
- Users cannot navigate between sections
- Appears as fundamental architecture problem
- Debugging is extremely difficult because selection state exists but doesn't work

**Prevention:**
```swift
// WRONG - Selection state exists but not bound
@State private var selectedItem: String?
NavigationSplitView {
    List(items) { item in
        NavigationLink(value: item) {
            Text(item.name)
        }
    }
} detail: {
    DetailView()
}

// CORRECT - Selection explicitly bound
@State private var selectedItem: String?
NavigationSplitView {
    List(items, selection: $selectedItem) { item in
        NavigationLink(value: item) {
            Text(item.name)
        }
    }
} detail: {
    DetailView()
}
```

**Detection:**
- Sidebar items highlight on tap but nothing happens
- NavigationLink works with explicit NavigationStack but not in NavigationSplitView
- Console may show warnings about unbound selection

**Which phase:** Phase 1 (Architecture Setup) - Must get this right when implementing NavigationSplitView structure

**Source confidence:** HIGH - Documented in [NavigationSplitView's Hidden Trap](https://theempathicdev.de/blog/advanced-navigation-split-view-bugs), [SwiftUI NavigationSplitView (Medium)](https://medium.com/@jpmtech/swiftui-navigationsplitview-30ce87b5de03)

---

### Pitfall 2: Navigation State Reset on Tab/Sidebar Mode Switch

**What goes wrong:**
When switching between iPhone (TabView) and iPad (Sidebar), or when rotating iPad from portrait to landscape, the navigation state resets completely. Users lose their position in the feed, selected item, and any navigation depth.

**Why it happens:**
Navigation state is treated as UI (view-local) rather than restorable data. When SwiftUI recreates the view hierarchy for different layouts, navigation state is lost because each tab/sidebar section doesn't maintain independent NavigationPath.

**Consequences:**
- User returns to root view unexpectedly when rotating iPad
- Deep links break when device switches between compact/regular size classes
- Lost scroll position in feed
- Poor user experience on iPad, especially with Stage Manager
- Navigation bugs are intermittent and hard to reproduce

**Prevention:**
1. **Give each section its own NavigationPath:**
```swift
@State private var homePath = NavigationPath()
@State private var captureePath = NavigationPath()
@State private var habitsPath = NavigationPath()
@State private var settingsPath = NavigationPath()

// Bind to each NavigationStack independently
NavigationStack(path: $homePath) {
    // Home content
}
```

2. **Persist navigation state in ViewModel, not in View:**
```swift
// WRONG - State lives in View
struct MainView: View {
    @State private var selectedPlaybook: UUID?
}

// CORRECT - State lives in persistent ViewModel
@Observable class NavigationState {
    var selectedPlaybook: UUID?
    var homePath = NavigationPath()
    var selectedTab: Tab = .home
}
```

3. **Use state restoration APIs:**
Implement SceneStorage for critical navigation state that should survive process termination.

**Detection:**
- Navigation resets when rotating iPad
- Switching tabs and returning clears navigation stack
- Deep links work initially but fail after rotation/size class change
- Test specifically with Stage Manager on iPad (frequent size class changes)

**Which phase:** Phase 1 (Architecture Setup) and Phase 4 (Polish) - Architecture must support it; polish phase validates across all device configurations

**Source confidence:** HIGH - Documented in [SwiftUI Navigation State Restoration](https://dev.to/sebastienlato/swiftui-navigation-state-restoration-cold-launch-deep-links-tabs-543c), [SwiftUI Sidebar doesn't remember state](https://developer.apple.com/forums/thread/653225), [Migrating to new navigation types](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)

---

### Pitfall 3: Image Memory Explosion in Feed Layout

**What goes wrong:**
As users scroll through the video feed, memory usage grows continuously until the app crashes with out-of-memory errors. Memory never gets released even when images scroll off-screen.

**Why it happens:**
SwiftUI's LazyVStack/List loads images into memory but doesn't properly release them when views are recycled. When displaying thumbnails in a feed (especially video thumbnails which can be large), memory accumulates. AsyncImage in particular wastes network I/O by re-fetching images that went off-screen.

**Consequences:**
- App crashes after scrolling through 50-100 videos
- Worse on older devices with less RAM
- Background app termination by iOS
- Poor App Store reviews mentioning crashes/slowness
- Critical blocker for users with large video libraries

**Prevention:**
1. **Store thumbnails in file system, not in memory/database:**
```swift
// WRONG - Loading full images into memory
@State private var videos: [VideoDTO] = []
ForEach(videos) { video in
    AsyncImage(url: video.fullImageURL) // Full image!
}

// CORRECT - Use thumbnail URLs and disk caching
ForEach(videos) { video in
    CachedAsyncImage(url: video.thumbnailURL) // Small thumbnail
}
```

2. **Generate and use appropriately-sized thumbnails:**
- Server should return thumbnail URL (320x180 for 16:9 thumbnails)
- Don't load full-size images for list/feed views
- Use thumbnail API endpoint, not full video metadata

3. **Implement proper image caching:**
```swift
// Use a library like Kingfisher or SDWebImageSwiftUI
// that handles memory/disk caching automatically
CachedAsyncImage(url: thumbnailURL) {
    // ...
}
.diskCache(enabled: true)
.memoryCache(maxSize: 50) // Limit in-memory cache
```

4. **Model data as relationships (if using Core Data/SwiftData):**
Don't store image data as attributes on main entities. Use separate entities for binary data so they're not loaded unless explicitly fetched.

**Detection:**
- Monitor memory usage in Xcode Memory Graph while scrolling
- Test with library of 100+ videos
- Memory continuously increases, never decreases
- Crash logs show memory exhaustion
- Performance degradation after scrolling

**Which phase:** Phase 2 (Feed/List Layout) - Must address when implementing thumbnail display

**Source confidence:** HIGH - Documented in [SwiftUI thumbnail image loading memory leak](https://developer.apple.com/forums/thread/773238), [How to limit memory usage of a list](https://developer.apple.com/forums/thread/668888), [How can I get SwiftUI to release cached image memory](https://www.hackingwithswift.com/forums/swiftui/how-can-i-get-swiftui-to-release-cached-image-memory/9862)

---

### Pitfall 4: Accessibility Regression During Redesign

**What goes wrong:**
The new sidebar and feed layouts work great visually but break completely for VoiceOver users. Dynamic Type support is lost, causing text to truncate at larger sizes. Users with accessibility needs cannot use the redesigned app.

**Why it happens:**
When redesigning UI, developers focus on visual appearance and forget to test with VoiceOver and Dynamic Type. Custom views may not inherit accessibility properly. Without regular accessibility testing during redesign, features degrade without anyone noticing until users complain.

**Consequences:**
- VoiceOver users cannot navigate the app
- Large text users see truncated, overlapping text
- Potential App Store rejection for accessibility violations
- Legal compliance issues (ADA, accessibility regulations)
- Excludes significant user segment (15%+ of iOS users use some accessibility feature)
- Bad publicity and App Store reviews

**Prevention:**
1. **Test with VoiceOver continuously during redesign:**
   - Enable VoiceOver on device/simulator
   - Navigate entire app with VoiceOver
   - Verify every interactive element has proper label
   - Test with eyes closed (real VoiceOver experience)

2. **Add explicit accessibility labels to custom views:**
```swift
// WRONG - Custom VideoGridItem with no accessibility
struct VideoGridItem: View {
    var body: some View {
        VStack {
            Image(systemName: "play.circle")
            Text(displayLabel)
        }
    }
}

// CORRECT - Proper accessibility
struct VideoGridItem: View {
    var body: some View {
        VStack {
            Image(systemName: "play.circle")
            Text(displayLabel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Video: \(displayLabel)")
        .accessibilityHint("Double tap to view details")
        .accessibilityAddTraits(.isButton)
    }
}
```

3. **Support Dynamic Type with scalable layouts:**
```swift
// WRONG - Fixed frame sizes
Text(title).frame(height: 20)

// CORRECT - Flexible layouts that scale
Text(title)
    .font(.headline)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // Cap if needed
    .lineLimit(2)
```

4. **Use Xcode Accessibility Inspector regularly:**
   - Settings > Accessibility > Display & Text Size > Larger Text
   - Test all screens at xxxLarge Dynamic Type
   - Run Accessibility Inspector audit

5. **Test toolbar/sidebar navigation with VoiceOver:**
   - Verify VoiceOver can access all navigation options
   - Confirm rotor navigation works correctly
   - Check that selected state is announced

**Detection:**
- Enable VoiceOver and try navigating
- Test with xxxLarge Dynamic Type setting
- Run Accessibility Inspector in Xcode (Product > Analyze > Accessibility)
- Text truncation, overlapping views at large text sizes
- VoiceOver announces unhelpful labels like "Button, Button"

**Which phase:** Continuously throughout Phase 1-4, with dedicated testing in Phase 4 (Polish)

**Source confidence:** HIGH - Documented in [How to Address Common Accessibility Challenges in iOS](https://www.freecodecamp.org/news/how-to-address-ios-accessibility-challenges-using-swiftui/), [Enhancing Your SwiftUI App with Dynamic Type and Accessibility](https://medium.com/@wesleymatlock/enhancing-your-swiftui-app-with-dynamic-type-and-accessibility-6b4bd84f4132)

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or require significant rework.

### Pitfall 5: SafeAreaInset Stacking Conflicts

**What goes wrong:**
After adding BulkActionBar using `.safeAreaInset(edge: .bottom)`, it overlaps with toolbar buttons or keyboard. When multiple bottom bars are needed (bulk actions + keyboard toolbar + tab bar), they stack unpredictably or cover content.

**Why it happens:**
Safe area insets work like a stack - each modifier appends its size to the inset. When toolbar components, safeAreaInset, and system UI (tab bar, keyboard) overlap, the combined height isn't calculated correctly. The order of modifiers matters but isn't obvious.

**Consequences:**
- Buttons unreachable behind keyboard
- Bulk action bar covers tab bar
- Content scrolls under bottom bars
- Inconsistent behavior between iPhone/iPad
- User complaints about "broken" UI
- Existing bug in Scrollsmith: "View Original button overlaps Create Action Points button"

**Prevention:**
1. **Use safeAreaInset instead of overlay for bottom bars:**
```swift
// WRONG - Overlay doesn't adjust safe area
.overlay(alignment: .bottom) {
    BulkActionBar()
}

// CORRECT - SafeAreaInset adjusts content
.safeAreaInset(edge: .bottom) {
    BulkActionBar()
}
```

2. **Be explicit about safe area edges:**
```swift
BulkActionBar()
    .background(.ultraThinMaterial)
    .ignoresSafeArea(edges: .horizontal) // Extend to edges
```

3. **Test with keyboard visible:**
   - Text input + bulk actions showing
   - Verify scrollable content adjusts correctly
   - Test on iPhone with different screen sizes

4. **Use zIndex when absolutely necessary:**
```swift
// Only if you need explicit stacking control
BulkActionBar()
    .zIndex(1) // Higher value = on top
```

5. **Consider new iOS safe area bar feature:**
   The WWDC25 "safe area bar" feature simplifies management of scroll view insets and overlays.

**Detection:**
- Buttons appear but can't be tapped (covered by another view)
- Content scrolls under bottom bars
- Keyboard pushes content but bars don't adjust
- Visual inspection shows overlapping views
- Test with keyboard, bulk actions, and tab bar all visible

**Which phase:** Phase 2 (Feed Layout) and Phase 3 (Bug Fixes) - Implement correctly in new layouts and fix existing overlap bugs

**Source confidence:** MEDIUM-HIGH - Documented in [Mastering Safe Area in SwiftUI](https://fatbobman.com/en/posts/safearea/), [How to control safe area insets in SwiftUI](https://www.fivestars.blog/articles/safe-area-insets/), Apple Forums discussions

---

### Pitfall 6: Conditional Views Not Updating in NavigationSplitView Columns

**What goes wrong:**
The detail column in NavigationSplitView shows stale content. Changing state that should update the detail view doesn't trigger a re-render. The sidebar selection changes but detail content stays frozen.

**Why it happens:**
Conditional views in NavigationSplitView columns fail to update on some state changes due to how SwiftUI optimizes column rendering. This is a known quirk specific to NavigationSplitView.

**Consequences:**
- Detail view shows wrong content for selected item
- State changes don't reflect in UI
- Appears like broken data binding
- Confuses users who see mismatched content
- Hard to debug because binding looks correct

**Prevention:**
1. **Wrap column contents in ZStack as workaround:**
```swift
// WORKAROUND for SwiftUI bug
NavigationSplitView {
    // sidebar
} detail: {
    ZStack {
        if let selected = selectedItem {
            DetailView(item: selected)
        } else {
            PlaceholderView()
        }
    }
}
```

2. **Use explicit id() modifier to force view updates:**
```swift
DetailView(item: selected)
    .id(selected.id) // Force recreation when selection changes
```

3. **Avoid deeply nested conditional views in columns:**
Keep column content simple, move complexity into child views.

**Detection:**
- Detail view doesn't update when selection changes
- Logging shows state changes but UI doesn't reflect them
- Works fine in regular NavigationStack but breaks in NavigationSplitView
- Test by rapidly changing sidebar selection

**Which phase:** Phase 1 (Architecture Setup) - Must catch this early when implementing NavigationSplitView

**Source confidence:** MEDIUM - Referenced in search results about NavigationSplitView issues, [Solving Common iOS NavigationStack Challenges](https://medium.com/@muhammadathief0/solving-common-ios-navigationstack-challenges-practical-solutions-based-on-my-experience-185c81a20940)

---

### Pitfall 7: Feed Performance Degradation with Complex Cards

**What goes wrong:**
Feed scrolling is janky at 30-45 FPS instead of smooth 60 FPS. Adding video thumbnails, creator info, and embedded YouTube previews causes noticeable lag. Users complain about "laggy" app.

**Why it happens:**
SwiftUI can struggle with complex cell layouts in lists. Expensive computations in the view hierarchy, unoptimized image loading, and excessive re-renders combine to kill performance. The new design adds complexity (thumbnails, metadata, buttons) that GridView's simple layout didn't have.

**Consequences:**
- Scrolling feels sluggish
- Dropped frames, visible jank
- Battery drain from excessive CPU usage
- Poor user experience, especially on older devices
- Negative App Store reviews

**Prevention:**
1. **Use LazyVStack in List (not just List alone) for complex layouts:**
```swift
// More efficient for complex custom cells
ScrollView {
    LazyVStack {
        ForEach(videos) { video in
            VideoFeedCard(video: video)
        }
    }
}
```

2. **Implement Equatable on card views to prevent unnecessary re-renders:**
```swift
struct VideoFeedCard: View, Equatable {
    let video: VideoDTO

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.video.id == rhs.video.id &&
        lhs.video.summaryBullets == rhs.video.summaryBullets
    }

    var body: some View {
        // Complex card layout
    }
}
```

3. **Move expensive computations out of body:**
```swift
// WRONG - Computed in body every render
var body: some View {
    let formattedDate = complexDateFormatting(video.createdAt)
    Text(formattedDate)
}

// CORRECT - Computed once, cached
@State private var formattedDate: String
var body: some View {
    Text(formattedDate)
}
.onAppear {
    formattedDate = complexDateFormatting(video.createdAt)
}
```

4. **Use Xcode SwiftUI Profiler (new in Xcode 26) to identify bottlenecks:**
   - Profile scrolling performance
   - Identify views causing hitches
   - Measure frame render times

5. **Optimize @Observable and @State usage:**
   Use @Observable for new ViewModels (more efficient than @ObservedObject)

6. **Lazy load expensive content (YouTube embeds):**
Don't load all YouTube players at once, only when scrolled into view.

**Detection:**
- Profile with SwiftUI Profiler in Xcode
- Monitor FPS while scrolling
- Test on older device (iPhone SE, iPad Air 2)
- User reports of "laggy" or "slow" scrolling
- Instruments shows high CPU usage during scroll

**Which phase:** Phase 2 (Feed Layout) - Build performance-optimized from the start

**Source confidence:** HIGH - Documented in [Debug SwiftUI Performance Issues (Jan 2026)](https://medium.com/@praveenkumar.idea/debug-swiftui-performance-issues-4c6edf87b759), [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps), [SwiftUI Performance Tuning](https://canopas.com/swiftui-performance-tuning-tips-and-tricks-a8f9eeb23ec4)

---

### Pitfall 8: YouTube Embed Integration Breaks Native Feel

**What goes wrong:**
Embedded YouTube players in the feed feel clunky and out of place. Videos don't respect system settings, drain battery excessively, or crash when scrolling quickly. Background audio playback violates YouTube TOS.

**Why it happens:**
YouTube integration in iOS requires WKWebView with iFrame embedding (AVPlayer doesn't work for YouTube). This brings web view overhead into a native SwiftUI app. Multiple simultaneous players, improper lifecycle management, or TOS-violating features cause problems.

**Consequences:**
- App feels like a web wrapper, not native
- Excessive battery drain
- Crashes when scrolling quickly through feed
- YouTube TOS violations risk app removal
- Poor video playback performance
- User complaints about "broken" videos

**Prevention:**
1. **Use YouTubePlayerKit Swift Package (recommended):**
```swift
import YouTubePlayerKit

YouTubePlayerView(player: player)
    .frame(height: 200)
```

2. **Don't violate YouTube TOS:**
   - No background audio playback (prohibited by TOS)
   - No simultaneous playback of multiple videos
   - Respect YouTube's embed policies

3. **Lazy load video players:**
```swift
// Don't create all players upfront
LazyVStack {
    ForEach(videos) { video in
        if video.hasYouTubeURL {
            YouTubePlayerView(player: video.player)
                .onAppear { video.player.load() }
                .onDisappear { video.player.pause() }
        }
    }
}
```

4. **Handle lifecycle properly:**
   - Pause videos when scrolled off-screen
   - Release players when view disappears
   - Don't keep multiple WKWebViews in memory

5. **Consider thumbnail-only approach for feed:**
   Show thumbnail + play button in feed, full player only in detail view

**Detection:**
- Test scrolling quickly through feed with many YouTube videos
- Monitor memory usage with multiple video players
- Battery drain test (Instruments Energy Log)
- Check YouTube TOS compliance
- User reports of crashes near video content

**Which phase:** Phase 2 (Feed Layout) - Plan integration carefully before implementing

**Source confidence:** HIGH - Documented in [YouTubePlayerKit GitHub](https://github.com/SvenTiigi/YouTubePlayerKit), [Integrating YouTube Videos in iOS SwiftUI Apps](https://md-hadi.medium.com/integrating-youtube-videos-in-ios-swiftui-apps-a-comprehensive-guide-d0df0fa6b396), [Using UIViewRepresentable to Render YouTube Videos](https://medium.com/@edabdallamo/using-uiviewrepresentable-to-render-youtube-videos-in-swiftui-962528791782)

---

### Pitfall 9: State Management Confusion During Redesign

**What goes wrong:**
During redesign, state management becomes inconsistent. Some views use @State, others @Observable, some @EnvironmentObject. Navigation state, selection state, and data state are entangled. Changes to one view trigger unexpected re-renders elsewhere.

**Why it happens:**
When redesigning UI, developers incrementally migrate views without establishing consistent state management patterns. Mixing old (@ObservedObject, @StateObject) and new (@Observable) APIs creates confusion. State that should be shared is duplicated, state that should be local is lifted.

**Consequences:**
- Difficult to reason about data flow
- Unexpected UI updates or lack of updates
- Memory leaks from retained view models
- Crashes from accessing deallocated state
- High bug count, hard to maintain
- Redesign takes much longer than planned

**Prevention:**
1. **Establish state management architecture BEFORE redesigning:**
   - Document what state belongs where
   - Choose @Observable consistently for new code
   - Don't mix paradigms unnecessarily

2. **Use @Observable for all new ViewModels:**
```swift
// NEW pattern (iOS 17+)
@Observable
class VideoFeedViewModel {
    var videos: [VideoDTO] = []
    var selectedVideo: VideoDTO?
}

// Use in view:
@State private var viewModel = VideoFeedViewModel()
```

3. **Keep navigation state separate from data state:**
```swift
// Navigation state
@State private var navigationState = NavigationState()

// Data state
@State private var videoViewModel = VideoViewModel()

// Don't mix them in one massive view model
```

4. **Document state ownership:**
   Create a STATE.md document showing which state lives where and why

5. **Migrate incrementally with clear boundaries:**
   Don't refactor everything at once. Migrate one section at a time with clear ownership.

**Detection:**
- Views re-rendering unnecessarily (use Self._printChanges())
- State changes don't trigger UI updates
- Mysterious crashes in view lifecycle
- Difficulty adding features due to unclear state flow
- Multiple sources of truth for same data

**Which phase:** Phase 0 (Planning) and Phase 1 (Architecture) - Establish patterns before implementation

**Source confidence:** MEDIUM-HIGH - Documented in [State Management in SwiftUI: The Complete Guide](https://dev.to/sebastienlato/state-management-in-swiftui-the-complete-guide-18fj), [Best Practices for State Management in SwiftUI](https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/8-best-practices-for-state-management-in-swiftui), [Fixing State Management Issues](https://www.mindfulchase.com/explore/troubleshooting-tips/fixing-state-management,-ui-rendering-delays,-and-animation-issues-in-swiftui.html)

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable without major rework.

### Pitfall 10: iPhone vs iPad Layout Not Tested Until Late

**What goes wrong:**
Sidebar looks great on iPad but completely broken on iPhone. Compact size class behavior wasn't considered. Features only work on one device type.

**Why it happens:**
Developers design and test on their primary device (usually iPhone or iPad) and forget to test the other form factor until late in development.

**Prevention:**
- Test both iPhone and iPad from day one
- Use Xcode preview with multiple device types
- Test compact and regular size classes explicitly
- Use adaptive layouts that work on both

**Detection:**
- UI broken on untested device type
- Layout doesn't adapt to size class changes
- Test early and often on both form factors

**Which phase:** Phase 1 (Architecture) and Phase 4 (Polish)

---

### Pitfall 11: Missing Empty States in New Feed Layout

**What goes wrong:**
New feed layout works great with data but shows blank screen when empty. No guidance for new users.

**Why it happens:**
During redesign, focus is on "happy path" with content. Empty states are forgotten until QA finds them.

**Prevention:**
- Design empty states upfront
- Use ContentUnavailableView
- Test with empty data from the start

**Detection:**
- Blank screens when data is empty
- Delete all content and check every screen

**Which phase:** Phase 2 (Feed Layout) - Design empty states with the feed

---

### Pitfall 12: Migration Breaks Existing User Flows

**What goes wrong:**
After redesign, users can't find familiar features. "Where did X go?" complaints flood reviews.

**Why it happens:**
Redesign changes navigation structure without considering existing mental models.

**Prevention:**
- Map old flows to new flows explicitly
- Consider feature discovery hints for existing users
- Beta test with real users before shipping
- Don't remove features without migration path

**Detection:**
- User complaints in reviews
- Support tickets asking "where is X?"
- Beta tester feedback

**Which phase:** Phase 4 (Polish) - User testing and feedback

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Phase 1: Architecture Setup** | NavigationSplitView selection binding forgotten | Double-check selection binding immediately; test navigation works before building detail views |
| **Phase 1: Architecture Setup** | Navigation state not separated by section | Create independent NavigationPath for each section from the start |
| **Phase 1: Architecture Setup** | Conditional views in columns not updating | Test detail view updates immediately; implement ZStack workaround if needed |
| **Phase 2: Feed Layout** | Image memory explosion | Implement thumbnail URLs and caching from day one; test with 100+ items |
| **Phase 2: Feed Layout** | Feed performance degradation | Profile performance early; implement Equatable; test on older device |
| **Phase 2: Feed Layout** | YouTube embed integration problems | Choose YouTubePlayerKit; plan lazy loading; respect TOS |
| **Phase 3: Bug Fixes** | SafeAreaInset stacking conflicts | Test button overlap bugs with keyboard and multiple bars visible |
| **Phase 4: Polish** | Accessibility regression | Test VoiceOver and Dynamic Type continuously, not at the end |
| **Phase 4: Polish** | iPhone vs iPad layout broken | Test both form factors throughout development |
| **All Phases** | State management confusion | Establish patterns in Phase 0; use @Observable consistently |

---

## Scrollsmith-Specific Warnings

Based on the existing codebase and known bugs:

### Existing Bug: Button Overlap
**Current issue:** "View Original button overlaps Create Action Points button"
**Related pitfall:** SafeAreaInset Stacking Conflicts (Pitfall #5)
**Fix in:** Phase 3 (Bug Fixes)
**Prevention:** Use proper safeAreaInset, test with all UI elements visible simultaneously

### Existing Bug: Non-functional Panels
**Current issue:** "Steps/cards panel not functional for free tier"
**Related pitfall:** State Management Confusion (Pitfall #9)
**Fix in:** Phase 3 (Bug Fixes)
**Prevention:** Clear state ownership for paywall/tier-gated features

### Risk: LazyVGrid → Feed Migration
**Current:** VideoGridView uses LazyVGrid with simple thumbnails
**New:** Feed layout with complex cards (thumbnails, metadata, YouTube)
**Related pitfall:** Feed Performance Degradation (Pitfall #7), Image Memory Explosion (Pitfall #3)
**Mitigation:** Profile performance early, implement thumbnail caching, test with large libraries

### Risk: Tab → Sidebar Migration
**Current:** MainTabView with 4 tabs (Home, Capture, Habits, Settings)
**New:** Sidebar navigation (Readwise Reader style)
**Related pitfall:** Navigation State Reset (Pitfall #2), NavigationSplitView Selection Binding (Pitfall #1)
**Mitigation:** Independent NavigationPath per section, explicit selection binding, test iPad rotation immediately

---

## Testing Checklist for UI Redesign

Before considering any phase complete:

**Navigation:**
- [ ] Sidebar selection binding works
- [ ] Navigation state persists across tab switches
- [ ] iPad rotation doesn't reset navigation
- [ ] Deep links work correctly
- [ ] Back navigation works as expected

**Performance:**
- [ ] Feed scrolls smoothly at 60 FPS
- [ ] Memory usage stays stable while scrolling
- [ ] Test with 100+ items in feed
- [ ] Test on iPhone SE or older iPad

**Accessibility:**
- [ ] VoiceOver can navigate entire app
- [ ] All interactive elements have labels
- [ ] xxxLarge Dynamic Type doesn't break layout
- [ ] Run Accessibility Inspector audit

**Cross-Platform:**
- [ ] Test on iPhone (compact size class)
- [ ] Test on iPad portrait (compact)
- [ ] Test on iPad landscape (regular)
- [ ] Test with Stage Manager (frequent size class changes)

**Edge Cases:**
- [ ] Empty states for all screens
- [ ] Keyboard doesn't cover inputs
- [ ] Button overlaps fixed
- [ ] All existing bugs verified fixed

---

## Sources

**HIGH Confidence (Official docs, Context7, well-documented issues):**
- [NavigationSplitView's Hidden Trap](https://theempathicdev.de/blog/advanced-navigation-split-view-bugs)
- [SwiftUI NavigationSplitView (Medium)](https://medium.com/@jpmtech/swiftui-navigationsplitview-30ce87b5de03)
- [SwiftUI Navigation State Restoration](https://dev.to/sebastienlato/swiftui-navigation-state-restoration-cold-launch-deep-links-tabs-543c)
- [Migrating to new navigation types - Apple](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)
- [SwiftUI thumbnail image loading memory leak](https://developer.apple.com/forums/thread/773238)
- [How to limit memory usage of a list](https://developer.apple.com/forums/thread/668888)
- [YouTubePlayerKit GitHub](https://github.com/SvenTiigi/YouTubePlayerKit)
- [Debug SwiftUI Performance Issues (Jan 2026)](https://medium.com/@praveenkumar.idea/debug-swiftui-performance-issues-4c6edf87b759)
- [How to Address Common Accessibility Challenges in iOS](https://www.freecodecamp.org/news/how-to-address-ios-accessibility-challenges-using-swiftui/)

**MEDIUM Confidence (Community discussions, multiple sources agreeing):**
- [Mastering Safe Area in SwiftUI](https://fatbobman.com/en/posts/safearea/)
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)
- [State Management in SwiftUI: The Complete Guide](https://dev.to/sebastienlato/state-management-in-swiftui-the-complete-guide-18fj)
- [Integrating YouTube Videos in iOS SwiftUI Apps](https://md-hadi.medium.com/integrating-youtube-videos-in-ios-swiftui-apps-a-comprehensive-guide-d0df0fa6b396)
- [Enhancing Your SwiftUI App with Dynamic Type and Accessibility](https://medium.com/@wesleymatlock/enhancing-your-swiftui-app-with-dynamic-type-and-accessibility-6b4bd84f4132)
