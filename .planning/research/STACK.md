# Stack Research: UI Polish Milestone (v1.1)

**Milestone:** Readwise Reader-inspired UI
**Researched:** 2026-01-29
**Focus:** SwiftUI patterns for sidebar navigation, video feed, YouTube player, card layouts
**Overall Confidence:** HIGH

---

**IMPORTANT:** This is milestone-specific research for UI polish. Base stack (SwiftUI, SwiftData, FastAPI, RevenueCat) is already validated and should NOT be changed.

---

## Executive Summary

All required UI patterns are available in native iOS 16-17+ SwiftUI. No third-party dependencies needed. The existing design system (Theme, StyledCard, ScrollsmithIcons) provides an excellent foundation.

**Key Decision:** Use `NavigationSplitView` (iOS 16+) for Readwise-style sidebar + detail layout, collapsing automatically on iPhone portrait.

## Recommended Stack

### Navigation Architecture

| Component | iOS Version | Purpose | Why |
|-----------|-------------|---------|-----|
| `NavigationSplitView` | 16.0+ | Sidebar + detail layout | Native master-detail, auto-adapts iPhone/iPad |
| `NavigationStack` | 16.0+ | Detail pane navigation | Multi-level navigation within detail |
| `.preferredCompactColumn()` | 17.0+ | iPhone layout control | Specify which column shows in portrait |
| Existing `TabView` | 13.0+ | Root-level tabs | Keep for Capture, Habits, Settings tabs |

**Integration Strategy:**
- Wrap Library tab content with `NavigationSplitView`
- Sidebar shows: All Videos, Types, Playbooks, Tags, Trash
- Detail shows video feed filtered by sidebar selection
- Automatically collapses to single column on iPhone portrait

**Why NavigationSplitView over TabView:**
NavigationSplitView is designed for hierarchical, master-detail relationships (Library → Playbooks → Videos), while TabView is for flat, category-based navigation. Readwise Reader uses sidebar navigation, which maps to NavigationSplitView.

### Video Feed / List

| Component | iOS Version | Purpose | Why |
|-----------|-------------|---------|-----|
| `LazyVGrid` | 14.0+ | Grid-based thumbnails | Lazy loading, adaptive columns, performance |
| `List` | 13.0+ | Linear list alternative | For list-style video feed option |
| `AsyncImage` | 15.0+ | Thumbnail loading | Native async image loading |
| Custom cache wrapper | N/A | Persistent caching | AsyncImage doesn't cache by default |
| `.task()` modifier | 15.0+ | Data loading | Auto-cancels on disappear (better than .onAppear) |
| `ContentUnavailableView` | 17.0+ | Empty states | Standard empty UI (no videos, search results) |

**Performance Pattern:**
```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
    ForEach(videos) { video in
        VideoCard(video: video)
    }
}
.task { await loadVideos() }
```

**Why LazyVGrid:**
- Loads views on-demand (not all upfront like ForEach)
- Adaptive columns respond to screen size automatically
- Already used in existing `VideoGridView.swift` (line 42)

### YouTube Player Embedding

| Technology | Approach | Why |
|-----------|----------|-----|
| `WKWebView` | YouTube iframe embed | Official method, no API key, handles all features |
| `UIViewRepresentable` | SwiftUI wrapper | Bridge UIKit WKWebView to SwiftUI |
| YouTube iframe API | HTML embed | Standard YouTube embedding (no TOS violations) |

**Recommended Implementation:**
```swift
struct YouTubePlayerView: UIViewRepresentable {
    let videoURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let embedHTML = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; padding: 0; }
                .video-container {
                    position: relative;
                    padding-bottom: 56.25%; /* 16:9 aspect ratio */
                    height: 0;
                    overflow: hidden;
                }
                .video-container iframe {
                    position: absolute;
                    top: 0; left: 0;
                    width: 100%; height: 100%;
                }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe src="\(videoURL.absoluteString)"
                        frameborder="0" allowfullscreen></iframe>
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(embedHTML, baseURL: nil)
    }
}
```

**Why WKWebView over Native:**
- Official YouTube embed method (no TOS violations)
- No API key or third-party SDK required
- Full YouTube features (controls, quality, captions, AirPlay, PiP)
- Simple integration (~20 lines of code)
- Existing app already has `WebView.swift` wrapper (can extend)

**Alternatives Considered & Rejected:**
- **YouTubeiOSPlayerHelper:** Deprecated, requires API key, unmaintained
- **AVPlayer + YouTube Data API:** Violates TOS, breaks frequently, no UI controls
- **Third-party SDKs:** Unnecessary complexity for simple embedding

### Card-Based Layouts

| Component | iOS Version | Purpose | Why |
|-----------|-------------|---------|-----|
| Existing `StyledCard` | N/A | Card wrapper | Already implements shadows, corners, padding |
| `.shadow()` modifier | 13.0+ | Depth elevation | Native, auto-disabled in dark mode |
| `.background(.ultraThinMaterial)` | 15.0+ | Glassmorphic blur | Modern iOS aesthetic, subtle depth |
| `RoundedRectangle` | 13.0+ | Card shape | Consistent corners via `Spacing.cardRadius` |

**Existing Design System (Use This):**
The app already has `Theme.cardShadow`:
```swift
static let cardShadow = Shadow(
    color: Color.black.opacity(0.08),
    radius: 3, x: 0, y: 1
)
```

And `StyledCard` component (`ios/Scrollsmith/Theme/Components/StyledCard.swift`):
```swift
struct StyledCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    var body: some View {
        content
            .padding(Spacing.cardPadding)
            .background(Theme.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .shadow(
                color: colorScheme == .light ? Theme.cardShadow.color : .clear,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
    }
}
```

**Implementation Pattern (Video Cards):**
```swift
struct VideoCard: View {
    let video: VideoDTO

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Thumbnail
            CachedAsyncImage(url: thumbnailURL) { image in
                image.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Theme.Background.tertiary)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay { ProgressView() }
            }
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))

            // Metadata
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(video.title).font(Typography.headline).lineLimit(2)
                HStack {
                    VideoSourceIcon(platform: .youtube, size: 16)
                    Text("Creator").font(Typography.caption)
                    Spacer()
                    Text("12:45").font(Typography.caption)
                }
            }
        }
        .cardStyle() // Uses existing StyledCard modifier
    }
}
```

**Why Use Existing Design System:**
- Consistent with current app aesthetic
- Dark mode handling already implemented
- Typography and spacing tokens defined
- Icons already created (ScrollsmithIcons.swift)

### SwiftData Integration

| Pattern | Purpose | Why |
|---------|---------|-----|
| `@Query` macro | Fetch videos | Auto-updates on data changes |
| Predicate filtering | Sidebar filters | Filter by playbook/tag selection |
| `.task(id:)` | Reload on selection | Re-query when sidebar changes |
| `FetchDescriptor` | Complex queries | Performance for large datasets |

**Query Pattern (Filtered by Selection):**
```swift
struct VideoFeedView: View {
    let filter: VideoFilter // from sidebar selection

    @Query var videos: [Video]

    init(filter: VideoFilter) {
        self.filter = filter

        let predicate: Predicate<Video>?
        switch filter {
        case .all:
            predicate = nil
        case .playbook(let id):
            predicate = #Predicate<Video> { video in
                video.playbooks.contains { $0.id == id }
            }
        case .tag(let name):
            predicate = #Predicate<Video> { video in
                video.tags?.contains(name) ?? false
            }
        case .trash:
            predicate = #Predicate<Video> { $0.deletedAt != nil }
        }

        _videos = Query(
            filter: predicate,
            sort: \.createdAt,
            order: .reverse
        )
    }
}
```

**Performance Note:**
`@Query` loads all matching objects into memory. For 500+ videos, implement pagination or limit initial results:
```swift
_videos = Query(
    filter: predicate,
    sort: \.createdAt,
    order: .reverse,
    animation: .default
)
// Then manually limit in view:
videos.prefix(50)
```

### Image Caching (AsyncImage Wrapper)

**Problem:** `AsyncImage` doesn't cache between screen loads. Same image re-downloads on scroll.

**Solution:** Custom wrapper using URLCache.

```swift
// Configure once in App init
class ImageCache {
    static let shared = ImageCache()

    private let cache = URLCache(
        memoryCapacity: 50_000_000,  // 50 MB
        diskCapacity: 200_000_000    // 200 MB
    )

    init() {
        URLCache.shared = cache
    }
}

// Usage in views
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                content(image)
            case .empty:
                placeholder()
            case .failure:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
    }
}
```

**Alternative:** Third-party `CachedAsyncImage` (lorenzofiamingo/swiftui-cached-async-image), but custom is simple and avoids dependency.

**Confidence:** MEDIUM - Pattern well-documented, but needs testing with URLCache configuration.

### YouTube Thumbnail Extraction

YouTube thumbnails available via predictable URL (no API key):

```swift
func youtubeThumbURL(videoId: String, quality: ThumbnailQuality = .medium) -> URL? {
    let baseURL = "https://i.ytimg.com/vi/\(videoId)/"
    let filename: String
    switch quality {
    case .default: filename = "default.jpg"      // 120x90
    case .medium:  filename = "mqdefault.jpg"    // 320x180
    case .high:    filename = "hqdefault.jpg"    // 480x360
    case .maxres:  filename = "maxresdefault.jpg" // 1280x720
    }
    return URL(string: baseURL + filename)
}

enum ThumbnailQuality {
    case `default`, medium, high, maxres
}
```

**Extract Video ID from URL:**
```swift
func extractYouTubeID(from urlString: String) -> String? {
    // youtube.com/watch?v=VIDEO_ID
    if let url = URL(string: urlString),
       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
        return videoId
    }
    // youtu.be/VIDEO_ID
    if urlString.contains("youtu.be/") {
        return urlString.components(separatedBy: "youtu.be/").last?
            .components(separatedBy: "?").first
    }
    return nil
}
```

**Confidence:** HIGH - Standard YouTube thumbnail URL format, no API required.

## What NOT to Use

### Anti-Pattern 1: NavigationView (Deprecated)
**Don't:** Use `NavigationView` with manual sidebar setup
**Why:** Deprecated in iOS 16+, NavigationSplitView is the replacement
**Use Instead:** `NavigationSplitView` for all master-detail layouts

### Anti-Pattern 2: AVPlayer for YouTube
**Don't:** Parse YouTube video streams and play with AVPlayer
**Why:** Violates YouTube TOS, breaks frequently, no UI controls
**Use Instead:** WKWebView with iframe embed (official method)

### Anti-Pattern 3: .onAppear for async loading
**Don't:** `.onAppear { Task { await loadData() } }`
**Why:** Task doesn't auto-cancel, can leak memory
**Use Instead:** `.task { await loadData() }` (iOS 15+)

### Anti-Pattern 4: Custom empty state views
**Don't:** Manual VStack + Image + Text for "No videos"
**Why:** Inconsistent with iOS, manual dark mode handling
**Use Instead:** `ContentUnavailableView` (iOS 17+)

### Anti-Pattern 5: ForEach for large lists
**Don't:** `ForEach` with all videos in VStack/ScrollView
**Why:** Loads all views upfront, poor performance with 100+ items
**Use Instead:** `LazyVStack`, `LazyVGrid`, or `List`

### Anti-Pattern 6: GeometryReader for responsive grids
**Don't:** GeometryReader to manually calculate grid columns
**Why:** Complex, fragile, doesn't handle orientation changes
**Use Instead:** `GridItem(.adaptive(minimum:))` for auto-responsive columns

## iOS Version Requirements

| Feature | Minimum iOS | Required? |
|---------|-------------|-----------|
| `NavigationSplitView` | 16.0+ | YES - core pattern |
| `NavigationStack` | 16.0+ | YES - detail navigation |
| `.preferredCompactColumn()` | 17.0+ | OPTIONAL - layout control |
| `ContentUnavailableView` | 17.0+ | YES - empty states |
| `.task()` | 15.0+ | YES - data loading |
| `AsyncImage` | 15.0+ | YES - image loading |
| `LazyVGrid` | 14.0+ | YES - grid layout |
| `@Query` | 17.0+ | YES (already required) |

**Target Deployment:** iOS 17.0+ (unchanged from existing app)

All recommended patterns available in iOS 17+.

## Architecture Diagram

```
NavigationSplitView
├── Sidebar (Primary)
│   ├── Section("Library")
│   │   └── "All Videos"
│   ├── Section("Types")
│   │   └── ForEach(types)
│   ├── Section("Playbooks")
│   │   └── ForEach(playbooks)
│   ├── Section("Tags")
│   │   └── ForEach(tags)
│   └── Section("System")
│       └── "Trash"
│
└── Detail (Secondary)
    └── NavigationStack
        ├── VideoFeedView
        │   ├── LazyVGrid
        │   │   └── VideoCard → VideoDetailView
        │   └── ContentUnavailableView (empty)
        │
        └── VideoDetailView
            ├── YouTubePlayerView (WKWebView)
            ├── ScrollView
            │   ├── Metadata (creator, duration)
            │   ├── Summary (bullets/cards)
            │   └── Habits
            └── Toolbar (share, favorite, delete)
```

## Implementation Phases

### Phase 1: Navigation Structure
- Replace PlaybookListView with NavigationSplitView
- Create SidebarView with sections
- Test iPhone/iPad collapse behavior

### Phase 2: Video Feed
- Implement CachedAsyncImage wrapper
- Create VideoCard using existing StyledCard
- Add YouTube thumbnail extraction

### Phase 3: YouTube Player
- Create YouTubePlayerView (WKWebView wrapper)
- Add to VideoDetailView above summary
- Test with playlists, live streams

### Phase 4: Polish
- Add ContentUnavailableView for empty states
- Implement .task for smooth loading
- Test performance with 100+ videos

## Sources

**NavigationSplitView:**
- [SwiftUI NavigationSplitView - Medium](https://medium.com/@jpmtech/swiftui-navigationsplitview-30ce87b5de03)
- [Exploring Navigation Split View](https://www.createwithswift.com/exploring-the-navigationsplitview/)
- [TN3154: Adopting NavigationSplitView - Apple](https://developer.apple.com/documentation/technotes/tn3154-adopting-swiftui-navigation-split-view)
- [Mastering NavigationSplitView - Swift with Majid](https://swiftwithmajid.com/2022/10/18/mastering-navigationsplitview-in-swiftui/)

**LazyVGrid Performance:**
- [SwiftUI Grid, LazyVGrid, LazyHGrid - avanderlee.com](https://www.avanderlee.com/swiftui/grid-lazyvgrid-lazyhgrid-gridviews/)
- [Tuning Lazy Stacks and Grids Performance - Medium](https://medium.com/@wesleymatlock/tuning-lazy-stacks-and-grids-in-swiftui-a-performance-guide-2fb10786f76a)

**YouTube Embedding:**
- [Implementing YouTube Player in SwiftUI - Medium](https://medium.com/@mikolukasik/implementing-a-youtube-player-in-swiftui-ff386fdfd1fb)
- [Custom YouTube Player with WKWebView - DEV](https://dev.to/fathima_a_1003/creating-a-custom-youtube-player-in-swiftui-using-wkwebview-4l44)
- [Integrating YouTube Videos in iOS - Medium](https://md-hadi.medium.com/integrating-youtube-videos-in-ios-swiftui-apps-a-comprehensive-guide-d0df0fa6b396)

**Card-Based UI:**
- [SwiftUI Card View Design - danijelavrzan.com](https://danijelavrzan.com/posts/2023/02/card-view-swiftui/)
- [Apple-Style Glassmorphic UI - DEV](https://dev.to/sebastienlato/how-to-build-apple-style-glassmorphic-ui-in-swiftui-3lgh)
- [Shadows and Color Opacity - Design+Code](https://designcode.io/swiftui-handbook-shadows-and-color-opacity/)

**AsyncImage Caching:**
- [AsyncImage with Caching - Matteo Manferdini](https://matteomanferdini.com/swiftui-asyncimage/)
- [Custom Cached AsyncImage - Medium](https://medium.com/@sviatoslav.kliuchev/improve-asyncimage-in-swiftui-5aae28f1a331)
- [Image Caching in SwiftUI - Create with Swift](https://www.createwithswift.com/image-caching-in-swiftui/)

**Readwise Reader:**
- [Reader Public Beta - Readwise Blog](https://blog.readwise.io/the-next-chapter-of-reader-public-beta/)
- [Readwise Reading App Architecture - Readwise Blog](https://blog.readwise.io/readwise-reading-app/)

**ContentUnavailableView:**
- [Handling Empty States - avanderlee.com](https://www.avanderlee.com/swiftui/contentunavailableview-handling-empty-states/)
- [Mastering ContentUnavailableView - Medium](https://medium.com/@gauravios/mastering-contentunavailableview-in-swiftui-the-new-elegant-empty-state-ui-dfa291d52372)

**SwiftData @Query:**
- [Query and Filter with SwiftData - swiftyplace](https://www.swiftyplace.com/blog/fetch-and-filter-in-swiftdata)
- [SwiftData @Query Tutorial - Big Mountain Studio](https://www.bigmountainstudio.com/blog/swiftdata-query)

**.task vs .onAppear:**
- [Task vs onAppear - DhiWise](https://www.dhiwise.com/post/swiftui-task-vs-onappear-choosing-the-right-approach)
- [Task vs onAppear - byby.dev](https://byby.dev/swiftui-task-vs-onappear)
- [Running Code When View Appears - Chris Eidhof](https://chris.eidhof.nl/post/swiftui-on-appear-vs-task/)

**YouTube Thumbnails:**
- [Retrieve YouTube Thumbnails - Medium](https://mohamed-abdo.medium.com/how-to-retrieve-youtube-video-thumbnails-using-youtube-api-and-direct-urls-adc8114ff318)

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| NavigationSplitView | HIGH | Official API (iOS 16+), production-proven |
| LazyVGrid performance | HIGH | Native component, already used in app |
| YouTube WKWebView | HIGH | Official embed method, app has WebView |
| Card design | HIGH | Existing StyledCard implements patterns |
| AsyncImage caching | MEDIUM | Pattern documented, needs URLCache testing |
| SwiftData integration | HIGH | Already using @Query in VideoGridView |
| iOS 17+ features | HIGH | All available in target deployment |

**Overall:** HIGH confidence. All patterns are native, well-documented, and align with existing codebase.

## Next Steps

No additional research required. All patterns mature and available in iOS 17+.

**Ready for implementation.**
