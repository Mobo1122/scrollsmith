# Research Summary: Scrollsmith v1.1 UI Polish

**Project:** Scrollsmith v1.1 - Readwise Reader-Inspired UI
**Domain:** iOS Read-It-Later App UI Redesign (Tab to Sidebar Navigation)
**Researched:** 2026-01-29
**Confidence:** HIGH

## Executive Summary

Scrollsmith v1.1 transforms from tab-based to sidebar navigation using native SwiftUI patterns. The recommended approach uses NavigationSplitView (iOS 16+) for automatic iPhone/iPad adaptation, List-based feeds for performance, and WKWebView for YouTube embedding. All patterns are native iOS 17+ features—no third-party dependencies required for core navigation.

The redesign is architecturally straightforward: wrap the existing tab content in NavigationSplitView, create a feed view using List with video cards, and implement sidebar filtering. The existing design system (StyledCard, Theme, ScrollsmithIcons) provides a solid foundation. The critical success factor is implementing navigation state management correctly from day one—NavigationSplitView has subtle requirements that, if missed, cause navigation to completely fail.

Key risks center on performance (feed with thumbnails and YouTube embeds) and state management (maintaining navigation paths across sidebar switches). The recommended phase order prioritizes establishing the navigation shell first, then building the feed, then fixing existing bugs. This minimizes risk by keeping existing views untouched until the new navigation structure is proven stable.

## Key Findings

### Recommended Stack

All required patterns are native SwiftUI components available in iOS 17+. The existing app already has the foundation (Theme, StyledCard, AsyncImage) and requires no new dependencies for core functionality.

**Core technologies:**
- **NavigationSplitView** (iOS 16+): Sidebar + detail layout — Apple's official pattern for master-detail UIs, automatically adapts iPhone/iPad without custom code
- **NavigationStack** (iOS 16+): Detail navigation — Enables drill-down (feed → video → habits) while preserving state
- **List + LazyVStack**: Feed layout — Native cell recycling for smooth 60fps scrolling with complex cards
- **WKWebView**: YouTube embedding — Official iframe embed method, no API key required, respects TOS
- **AsyncImage + URLCache**: Image caching — Native image loading with custom cache wrapper (50MB memory, 200MB disk)
- **Existing Theme system**: Design tokens — StyledCard, Typography, ScrollsmithIcons already implement desired aesthetic

**Critical version requirements:**
- iOS 17.0+ deployment target (already set)
- NavigationSplitView, NavigationStack, ContentUnavailableView all available

### Expected Features

Research identified production-grade patterns from Readwise Reader, Pocket, and Instapaper. The table stakes are well-documented; differentiators focus on triage workflows and visual polish.

**Must have (table stakes):**
- **Sidebar Navigation** — Industry standard for content curation apps (Library/Types/Playbooks sections with drag-to-reorder)
- **Content Cards** — Preferred over simple lists for heterogeneous video content (thumbnail, title, creator, duration, status badge)
- **Pull-to-Refresh** — Universal mobile gesture with haptic feedback at trigger point
- **Skeleton Screens** — Modern loading pattern (shows layout wireframe during load, reduces perceived wait time)
- **Dark Mode** — Expected for reading apps to reduce eye strain (system detection + manual override)
- **Empty States** — Critical onboarding opportunity using ContentUnavailableView (iOS 17+)
- **Search + Filters** — Essential as library grows (real-time search <200ms, tag/playbook/date filters)
- **Swipe Gestures** — Mobile-native triage (left/right swipes for Archive/Later/Delete)
- **Visual Hierarchy** — Guide attention with card hierarchy (thumbnail largest, title bold, metadata secondary)
- **Haptic Feedback** — Makes interactions tangible (light on swipe threshold, medium on archive, heavy on delete)

**Should have (competitive differentiators):**
- **Customizable Sidebar Views** — Power user feature for filtered views (e.g., "Unwatched This Week")
- **Content Status Badges** — Visual indicator on cards (Inbox/Later/Archive with colored dots)
- **Progress Indicators** — Show watch progress on video cards (45% watched bar on thumbnail)
- **TikTok-Inspired Feed** — Vertical full-screen triage with swipe-up to advance (game-like workflow)
- **Daily Digest View** — Curated "Saved for Later" queue in scrollable triage format

**Defer (v2+):**
- Annotation system (high complexity, niche use case)
- E-ink mode (very niche audience)
- Triage keyboard shortcuts (desktop/web only)
- Long-form reading view (nice-to-have polish)
- Paged scroll navigation (experimental, unclear value for video)

**Anti-features to avoid:**
- Hamburger menu on iPad (use persistent sidebar)
- Auto-play previews in feed (battery drain, annoying)
- Nested folder hierarchies (use flat tags + filtered views)
- Social features (scope creep, not core to "second brain" use case)
- Generic loading spinners (use skeleton screens instead)
- Infinite scroll without progress indicators (use "showing 1-20 of 50")

### Architecture Approach

The migration strategy minimizes risk by preserving all existing views and only changing the navigation container. NavigationSplitView replaces MainTabView, with 3-4 new files creating the shell while 30+ existing views remain untouched.

**Major components:**
1. **RootNavigationView** (new) — NavigationSplitView container managing sidebar + detail layout with columnVisibility state
2. **SidebarView** (new) — Sidebar content with Library/Types/Playbooks sections, selection binding drives detail view updates
3. **DetailRouter** (new) — Routes sidebar selection to appropriate detail view using enum-based type-safe switching
4. **VideoFeedView** (new) — List-based feed with VideoCard components, replaces grid for "All Videos" view
5. **VideoCardView** (new) — Individual card with thumbnail (CachedAsyncImage), title, creator, duration using existing StyledCard
6. **VideoGridView** (reuse) — Existing grid view preserved for filtered views (playbooks, tags)
7. **CaptureView** (reuse) — Presented as fullScreenCover modal, not sidebar item
8. **HabitListView** (reuse) — Added as sidebar item or modal (decision point)

**Navigation data flow:**
User taps sidebar → RootNavigationView updates @State selection → DetailRouter observes change → Routes to VideoFeedView/VideoGridView/SettingsView → NavigationStack handles drill-down → State preserved per sidebar section

**Migration phases:**
- Phase 1: Navigation shell (4 new files, 1 modified) — Low risk, existing views untouched
- Phase 2: Video feed (3 new files) — Medium risk, new API-dependent view
- Phase 3: Sidebar population (2 files modified) — Low risk, reuses existing VideoGridView
- Phase 4: Modal actions (1-2 files modified) — Low risk, standard modal patterns
- Phase 5: iPad polish (2-3 files modified) — Low risk, optional optimization

**File structure impact:**
- New: Views/Navigation/ folder (3 files)
- New: Views/Videos/VideoFeedView.swift, VideoCardView.swift
- New: ViewModels/VideoFeedViewModel.swift
- Modified: ContentView.swift (MainTabView → RootNavigationView)
- Deprecated: MainTabView.swift (remove after migration)
- Unchanged: All 30+ files in Auth/, Capture/, Habits/, Playbooks/, Summary/, Settings/

### Critical Pitfalls

Research identified 9 critical/moderate pitfalls specific to SwiftUI sidebar redesigns. Top 5 with highest impact:

1. **NavigationSplitView Selection Binding Forgotten** — Selection state exists but isn't bound to List; sidebar appears functional but navigation completely broken. Prevention: Explicitly bind `List(items, selection: $selectedItem)` in sidebar. Detection: Items highlight but nothing happens. Phase: Must fix in Phase 1.

2. **Navigation State Reset on Tab/Sidebar Switch** — Rotating iPad or switching sidebar items resets navigation to root; users lose their place. Prevention: Maintain independent NavigationPath per sidebar section in ViewModel (not View-local @State). Detection: Test iPad rotation immediately. Phase: Architecture in Phase 1, validation in Phase 4.

3. **Image Memory Explosion in Feed** — Scrolling through 50+ videos causes memory to grow until crash; AsyncImage doesn't release images. Prevention: Use thumbnail URLs (not full images), implement disk caching with URLCache, generate 320x180 thumbnails server-side. Detection: Instruments Memory Graph shows continuous growth. Phase: Must address in Phase 2.

4. **Feed Performance Degradation** — Complex video cards (thumbnail + metadata + buttons) cause scrolling to drop to 30-45 FPS. Prevention: Implement Equatable on VideoCardView, move computations out of body, profile with SwiftUI Profiler, test on older device (iPhone SE). Detection: Frame rate monitor in Xcode. Phase: Build performance-first in Phase 2.

5. **Accessibility Regression** — VoiceOver breaks, Dynamic Type truncates text; redesign focuses on visual appearance and forgets accessibility testing. Prevention: Test VoiceOver continuously, add explicit accessibilityLabel/Hint to custom views, support Dynamic Type up to xxxLarge, run Accessibility Inspector audit. Detection: Enable VoiceOver and try navigating. Phase: Continuous testing in all phases, dedicated validation in Phase 4.

**Additional notable pitfalls:**
- SafeAreaInset stacking conflicts (existing bug: button overlap) — Use safeAreaInset for bottom bars, test with keyboard + toolbar + bulk actions all visible
- YouTube embed lifecycle issues — Use lazy loading, pause offscreen players, respect TOS (no background audio)
- State management confusion during redesign — Establish @Observable patterns before coding, separate navigation state from data state

## Implications for Roadmap

Based on combined research, recommended 4-phase structure prioritizing low-risk navigation foundation, then feed implementation, then bug fixes, then polish.

### Phase 1: Navigation Architecture
**Rationale:** Establish NavigationSplitView foundation before building features on top. This phase creates the shell without touching existing views, minimizing breakage risk. Testing sidebar selection binding early prevents critical Pitfall #1.

**Delivers:**
- RootNavigationView with sidebar + detail layout
- SidebarView with Library, Types, Playbooks sections (initially hardcoded)
- DetailRouter routing sidebar selection to existing views
- iPhone/iPad automatic adaptation verified

**Addresses features:**
- Sidebar Navigation (table stakes)
- iPhone vs iPad layout adaptation

**Avoids pitfalls:**
- #1 (NavigationSplitView selection binding) — Test immediately
- #2 (Navigation state reset) — Architect independent NavigationPath per section upfront
- #6 (Conditional views not updating) — Implement ZStack workaround if needed

**Migration strategy:**
- Create 3 new files (RootNavigationView, SidebarView, DetailRouter)
- Create SidebarItem enum for type-safe routing
- Modify ContentView.swift (MainTabView → RootNavigationView)
- No changes to existing 30+ view files
- Test on both iPhone and iPad before proceeding

**Research flag:** Standard pattern, no additional research needed (HIGH confidence in Apple docs)

### Phase 2: Video Feed & Cards
**Rationale:** Feed is the core UX change and has highest risk (performance, memory, API dependencies). Building it in Phase 2 (after navigation shell proven) allows focused testing of new patterns while keeping fallback to Phase 1 navigation if needed.

**Delivers:**
- VideoFeedView with List-based layout
- VideoCardView using existing StyledCard design system
- CachedAsyncImage wrapper with URLCache configuration
- YouTube thumbnail extraction from video URLs
- Pull-to-refresh, skeleton screens, empty states
- NavigationLink to existing SummaryDisplayView

**Addresses features:**
- Content Cards (table stakes)
- Pull-to-Refresh (table stakes)
- Skeleton Screens (table stakes)
- Empty States (table stakes)
- Visual Hierarchy (table stakes)

**Uses stack:**
- List + LazyVStack for performance
- AsyncImage with URLCache for caching
- YouTube thumbnail API (i.ytimg.com/vi/{id}/mqdefault.jpg)
- Existing StyledCard, Theme, Typography

**Avoids pitfalls:**
- #3 (Image memory explosion) — Implement thumbnail URLs + disk caching from day one
- #4 (Feed performance) — Profile early, implement Equatable on VideoCardView, test with 100+ videos
- #7 (Feed performance at scale) — Use List (not LazyVStack), test on iPhone SE

**Performance targets:**
- 60 FPS scrolling with 100+ videos
- Memory stable during scroll (test with Instruments)
- <200ms thumbnail load time
- <1s feed initial load

**Research flag:** Medium complexity—pagination patterns need iteration. Standard List patterns (HIGH confidence), but pagination best practices vary (MEDIUM confidence). Plan to iterate based on performance testing.

### Phase 3: Sidebar Population & Bug Fixes
**Rationale:** With navigation and feed proven, populate sidebar with dynamic content (playbooks, tags) and fix existing bugs. This phase reuses existing VideoGridView for filtered views, minimizing new code. Fixing bugs (button overlap, non-functional panels) ensures v1.1 doesn't ship with known issues.

**Delivers:**
- Types section (YouTube, Camera Roll) routing to filtered VideoGridView
- Playbooks section with ForEach(playbooks) routing to filtered VideoGridView
- Tags section (future placeholder)
- Trash section (future placeholder)
- Fix: "View Original button overlaps Create Action Points button"
- Fix: "Steps/cards panel not functional for free tier"

**Addresses features:**
- Sidebar filtering (table stakes)
- Search + Filters (table stakes)
- Playbook organization (existing feature, new UI)

**Bug fixes implementation:**
- Button overlap: Use safeAreaInset for bottom bars, test with keyboard + toolbar visible
- Non-functional panels: Clear state ownership for paywall-gated features

**Avoids pitfalls:**
- #5 (SafeAreaInset stacking) — Test button overlap with all UI elements visible simultaneously
- #9 (State management confusion) — Document state ownership for tier-gated features

**Research flag:** Standard filtering patterns, no additional research needed (HIGH confidence)

### Phase 4: Triage & Polish
**Rationale:** With core functionality complete, add differentiating triage features and polish iPad experience. This phase is optional for MVP but elevates the app from functional to delightful. Accessibility validation happens here to ensure no regressions.

**Delivers:**
- Swipe gestures on cards (Archive/Later/Delete)
- Haptic feedback for swipe actions
- Content status badges on cards (Inbox/Later/Archive)
- Progress indicators (watch progress bars)
- Customizable swipe actions in Settings
- iPad-specific optimizations (.navigationSplitViewStyle(.balanced))
- Accessibility validation (VoiceOver, Dynamic Type, Accessibility Inspector audit)

**Addresses features:**
- Swipe Gestures (table stakes)
- Haptic Feedback (table stakes)
- Content Status Badges (differentiator)
- Progress Indicators (differentiator)
- Typography Customization (table stakes for reading apps)

**Avoids pitfalls:**
- #5 (Accessibility regression) — Dedicated VoiceOver testing, Dynamic Type testing up to xxxLarge
- #10 (iPhone vs iPad not tested) — Test both form factors, test iPad rotation, test Stage Manager

**Polish checklist:**
- VoiceOver can navigate entire app
- xxxLarge Dynamic Type doesn't break layout
- Haptics work on device (not Simulator)
- Swipe gestures feel natural (test threshold distances)
- iPad sidebar looks polished in landscape

**Research flag:** Swipe gesture UX may need iteration—no single authoritative pattern for threshold distances and feedback timing. Plan user testing to validate feel. Haptics require device testing (Simulator doesn't support haptics).

### Phase Ordering Rationale

**Why this order:**
1. **Navigation first** — Foundation for everything else; testing early catches critical Pitfall #1
2. **Feed second** — Highest risk (performance, memory); building on proven navigation allows focused testing
3. **Sidebar population third** — Reuses existing VideoGridView; low risk once feed patterns proven
4. **Polish last** — Differentiators that can be deferred; accessibility validation ensures no regressions

**Dependency chain:**
- Phase 2 depends on Phase 1 (feed needs navigation shell)
- Phase 3 depends on Phase 2 (sidebar filtering uses feed patterns)
- Phase 4 depends on Phase 3 (polish applies to complete feature set)

**Risk mitigation:**
- Each phase independently testable and shippable
- Existing views untouched until Phase 4
- Performance testing happens in Phase 2 (early detection)
- Accessibility testing continuous, validated in Phase 4

**Minimum viable shipment:** After Phase 3 (functional parity + new feed UI)

**Recommended MVP:** After Phase 2 (new feed works, basic sidebar functional)

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 2 (Feed):** Pagination patterns vary across sources; may need iteration to find performant approach. Start with .onAppear on last item (most common), measure performance with Instruments, adjust if needed.
- **Phase 4 (Triage):** Swipe gesture thresholds and haptic timing lack authoritative guidance. Plan user testing to validate feel (light/medium/heavy haptics, short/long swipe distances).

**Phases with standard patterns (skip research):**
- **Phase 1 (Navigation):** NavigationSplitView is official Apple pattern with authoritative documentation (TN3154, developer.apple.com). No additional research needed.
- **Phase 3 (Sidebar Population):** SwiftData @Query filtering is well-documented and already used in existing VideoGridView. No additional research needed.

**Performance validation points:**
- Phase 2: Profile feed scrolling with SwiftUI Profiler (Xcode 16+)
- Phase 2: Memory testing with Instruments (Memory Graph, Leaks)
- Phase 2: Test with 100+ videos on iPhone SE or older iPad
- Phase 4: Test haptics on physical device (Simulator doesn't support)

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All patterns native iOS 17+, documented in Apple developer docs; NavigationSplitView, NavigationStack established since iOS 16 |
| Features | MEDIUM-HIGH | Table stakes verified across Readwise Reader, Pocket, Instapaper; some differentiators (TikTok feed, annotations) have less documentation |
| Architecture | HIGH | Migration strategy preserves existing views; phased approach minimizes risk; file structure changes clearly scoped |
| Pitfalls | HIGH | NavigationSplitView selection binding, navigation state reset, image memory issues well-documented in Apple forums and community sources |

**Overall confidence:** HIGH

The recommended approach uses established patterns with authoritative sources. The primary uncertainty is performance tuning (pagination strategies, image caching thresholds) which requires iteration rather than upfront research.

### Gaps to Address

**Performance at scale:**
Research covered patterns for 100+ items but actual performance depends on Scrollsmith's specific data (thumbnail sizes, metadata complexity, API response times). Plan to validate with real data:
- Load 200+ videos during Phase 2 testing
- Profile with SwiftUI Profiler and Instruments
- Test on iPhone SE 3rd gen (lowest-spec target device)
- Iterate pagination if needed

**Swipe gesture UX:**
Research shows swipe gestures are standard (Mail, Reminders) but threshold distances and haptic timing lack specific guidance. Plan user testing:
- Prototype short/long swipe thresholds in Phase 4
- Test light/medium/heavy haptics for Archive/Delete
- Validate with 5-10 users before finalizing

**Navigation path state preservation:**
NavigationSplitView doesn't automatically preserve navigation paths when switching sidebar items (known SwiftUI limitation as of iOS 17-18). Workaround available (path dictionary pattern) but adds complexity:
- Defer implementation until Phase 4 user testing
- Only implement if users report confusion
- Medium confidence in workaround (reported working in forums, not officially documented)

**AsyncImage caching performance:**
Pattern documented but URLCache configuration needs validation with real thumbnail sizes:
- Start with 50MB memory, 200MB disk (recommended values)
- Monitor cache hit rates during Phase 2 testing
- Consider third-party library (Kingfisher) if performance issues emerge

**Video-specific patterns:**
Research focused on text-based read-it-later apps; video content may need adapted patterns:
- Thumbnail quality balance (size vs quality)
- Duration indicators (placement, format)
- Preview on long-press (battery implications)
- Validate these in Phase 2 prototyping

## Sources

### Primary (HIGH confidence)

**Apple Official Documentation:**
- [NavigationSplitView - Apple Developer](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [TN3154: Adopting NavigationSplitView - Apple](https://developer.apple.com/documentation/technotes/tn3154-adopting-swiftui-navigation-split-view)
- [Migrating to new navigation types - Apple](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)

**Established SwiftUI Experts:**
- [Mastering NavigationSplitView - Swift with Majid](https://swiftwithmajid.com/2022/10/18/mastering-navigationsplitview-in-swiftui/)
- [Deep Dive into Modern SwiftUI Navigation - Fatbobman](https://fatbobman.com/en/posts/new_navigator_of_swiftui_4/)
- [NavigationSplitView's Hidden Trap - The Empathic Dev](https://theempathicdev.de/blog/advanced-navigation-split-view-bugs)

**Readwise Reader Research:**
- [Readwise & Reader Changelog](https://docs.readwise.io/changelog)
- [Navigation - Readwise Docs](https://docs.readwise.io/reader/docs/faqs/navigation)
- [Getting Started with Reader](https://blog.readwise.io/p/bf87944f-b0fe-4f08-a461-f75ab8aded6a/)

**Performance & Accessibility:**
- [SwiftUI Scroll Performance: The 120FPS Challenge - Jacob's Tech Tavern](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps) (2025)
- [Debug SwiftUI Performance Issues - Medium](https://medium.com/@praveenkumar.idea/debug-swiftui-performance-issues-4c6edf87b759) (Jan 2026)
- [How to Address Common Accessibility Challenges in iOS - freeCodeCamp](https://www.freecodecamp.org/news/how-to-address-ios-accessibility-challenges-using-swiftui/)

**Apple Developer Forums (Critical Pitfalls):**
- [SwiftUI thumbnail image loading memory leak - Thread 773238](https://developer.apple.com/forums/thread/773238)
- [How to limit memory usage of a list - Thread 668888](https://developer.apple.com/forums/thread/668888)
- [Persist navigation paths in NavigationSplitView - Thread 741538](https://developer.apple.com/forums/thread/741538)

### Secondary (MEDIUM confidence)

**SwiftUI Navigation:**
- [Exploring the Navigation Split View - Create with Swift](https://www.createwithswift.com/exploring-the-navigationsplitview/)
- [SwiftUI Split View Configuration - Use Your Loaf](https://useyourloaf.com/blog/swiftui-split-view-configuration/)
- [Getting started with NavigationSplitView - Daniel Saidi](https://danielsaidi.com/blog/2022/08/08/getting-started-with-the-SwiftUI-navigation-split-view)

**YouTube Embedding:**
- [YouTubePlayerKit GitHub - Sven Tiigi](https://github.com/SvenTiigi/YouTubePlayerKit)
- [Integrating YouTube Videos in iOS SwiftUI Apps - Medium](https://md-hadi.medium.com/integrating-youtube-videos-in-ios-swiftui-apps-a-comprehensive-guide-d0df0fa6b396)
- [Implementing YouTube Player in SwiftUI - Medium](https://medium.com/@mikolukasik/implementing-a-youtube-player-in-swiftui-ff386fdfd1fb)

**Feed Performance:**
- [The Next Page: Building Infinite Scroll - Whatnot Engineering](https://medium.com/whatnot-engineering/the-next-page-8950875d927a)
- [Tuning Lazy Stacks and Grids Performance - Medium](https://medium.com/@wesleymatlock/tuning-lazy-stacks-and-grids-in-swiftui-a-performance-guide-2fb10786f76a)

**UX Best Practices:**
- [Top UI UX Design Best Practices for 2026 - UI Designz](https://uidesignz.com/blogs/ui-ux-design-best-practices)
- [Cards design pattern - UI Patterns](https://ui-patterns.com/patterns/cards)
- [Skeleton Screens 101 - Nielsen Norman Group](https://www.nngroup.com/articles/skeleton-screens/)
- [Pull to refresh design pattern - UI Patterns](https://ui-patterns.com/patterns/pull-to-refresh)

**State Management:**
- [State Management in SwiftUI: The Complete Guide - DEV](https://dev.to/sebastienlato/state-management-in-swiftui-the-complete-guide-18fj)
- [SwiftUI Navigation State Restoration - DEV](https://dev.to/sebastienlato/swiftui-navigation-state-restoration-cold-launch-deep-links-tabs-543c)

**Safe Area & Layout:**
- [Mastering Safe Area in SwiftUI - Fatbobman](https://fatbobman.com/en/posts/safearea/)
- [How to control safe area insets in SwiftUI - Fivestars Blog](https://www.fivestars.blog/articles/safe-area-insets/)

### Tertiary (needs validation)

**Image Caching:**
- [AsyncImage with Caching - Matteo Manferdini](https://matteomanferdini.com/swiftui-asyncimage/)
- [Custom Cached AsyncImage - Medium](https://medium.com/@sviatoslav.kliuchev/improve-asyncimage-in-swiftui-5aae28f1a331)
- Note: URLCache configuration needs validation with Scrollsmith's thumbnail sizes

**Pagination Patterns:**
- Multiple sources show different approaches (.onAppear, .task, custom triggers)
- No single authoritative pattern—needs performance testing to determine best approach for Scrollsmith

---

*Research completed: 2026-01-29*
*Ready for roadmap: Yes*
*Recommended next step: Create roadmap with 4 phases (Navigation → Feed → Population → Polish)*
