# Phase 14: Video Feed & Cards - Research

**Researched:** 2026-01-31
**Domain:** SwiftUI List-based feeds with async image loading and caching
**Confidence:** HIGH

## Summary

Phase 14 transforms VideoFeedView from a basic list with placeholder thumbnails into a rich, performant feed with real thumbnails, skeleton loading, and empty states. The research focused on SwiftUI feed performance patterns, image caching solutions, and iOS 17 native UI components.

The standard approach is to use SwiftUI's **List** (not LazyVStack) for better scrolling performance with 100+ items, **Kingfisher** for production-grade image caching with automatic disk cache management, and iOS 17's native **ContentUnavailableView** for empty states. Skeleton loading uses SwiftUI's built-in **.redacted(reason: .placeholder)** modifier which works seamlessly with List.

**Critical discovery:** VideoDTO currently lacks a `thumbnailUrl` field. Backend must add this field to the API response before iOS can display real thumbnails. YouTube thumbnails follow predictable URL patterns (`https://img.youtube.com/vi/<video_id>/maxresdefault.jpg`), making backend extraction straightforward.

**Primary recommendation:** Keep List-based architecture (already exists), add Kingfisher via SPM for image caching, implement .redacted() for skeleton states, use ContentUnavailableView for empty state, and coordinate with backend to add thumbnail URLs to VideoDTO response.

## Standard Stack

The established libraries/tools for SwiftUI feed implementation with images:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI List | iOS 17+ | Feed container | UICollectionView-backed since iOS 16, outperforms LazyVStack for large datasets with built-in cell recycling |
| Kingfisher | 8.0+ | Image loading & caching | Industry standard, 24k+ stars, native SwiftUI support via KFImage, two-tier memory+disk cache, Swift 6 ready |
| ContentUnavailableView | iOS 17+ | Empty states | Native iOS 17 component, automatically localized, consistent with system design |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| .redacted() modifier | iOS 14+ | Skeleton loading | Built-in SwiftUI, single-line implementation, works with List |
| AsyncImage | iOS 15+ | Basic image loading | Only if avoiding dependencies, lacks disk cache and must configure URLCache manually |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Kingfisher | SDWebImageSwiftUI | More formats (GIF/APNG/WebP) but heavier, Kingfisher is lighter and sufficient for video thumbnails |
| Kingfisher | CachedAsyncImage libraries | Smaller packages but less battle-tested, Kingfisher has 8+ years of production use |
| List | LazyVStack | More layout flexibility but 10x slower scrolling (5.5s vs 52s to scroll 100+ items), worse memory usage |
| .redacted() | Custom skeleton | More control over shimmer but requires iOS version targeting, .redacted() is simpler |

**Installation:**
```bash
# Add via Xcode > File > Add Package Dependencies
# https://github.com/onevcat/Kingfisher.git
# Minimum version: 8.0.0
```

## Architecture Patterns

### Recommended Feed Structure
```
Views/
├── Videos/
│   ├── VideoFeedView.swift           # List container with loading/empty states
│   ├── VideoFeedRow.swift            # Individual row with KFImage thumbnail
│   └── VideoFeedSkeletonRow.swift   # Skeleton placeholder (optional, can use .redacted())
```

### Pattern 1: List-Based Feed (Current Architecture - Keep It)
**What:** SwiftUI List with NavigationLink(value:) pattern for navigation
**When to use:** Feeds with 20+ items, especially when performance on older devices (iPhone SE) is critical
**Why this works:** List uses UICollectionView since iOS 16, provides automatic cell recycling, and maintains 60 FPS with 100+ items

**Example:**
```swift
// Source: Current VideoFeedView.swift (already correct pattern)
List {
    ForEach(videos) { video in
        NavigationLink(value: video) {
            VideoFeedRow(video: video)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}
.listStyle(.plain)
```

### Pattern 2: KFImage for Cached Thumbnails
**What:** Kingfisher's SwiftUI component with automatic caching
**When to use:** Any remote image in a scrollable feed
**Example:**
```swift
// Source: https://github.com/onevcat/Kingfisher/wiki/SwiftUI-Support
import Kingfisher

struct VideoFeedRow: View {
    let video: VideoDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KFImage(URL(string: video.thumbnailUrl ?? ""))
                .placeholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: 100, height: 60)
                .cornerRadius(8)
                .cancelOnDisappear()  // Cancels download when scrolled off-screen

            // ... metadata
        }
    }
}
```

### Pattern 3: Skeleton Loading with .redacted()
**What:** SwiftUI's built-in placeholder modifier
**When to use:** Initial load state while API fetches videos
**Example:**
```swift
// Source: https://www.avanderlee.com/swiftui/redacted-view-modifier/
@State private var isLoading = false
@State private var videos: [VideoDTO] = []

var body: some View {
    List {
        ForEach(isLoading ? VideoDTO.placeholderArray() : videos) { video in
            VideoFeedRow(video: video)
        }
    }
    .redacted(reason: isLoading ? .placeholder : [])
}
```

### Pattern 4: Empty State with ContentUnavailableView
**What:** iOS 17 native empty state component
**When to use:** No videos exist after loading completes
**Example:**
```swift
// Source: https://developer.apple.com/documentation/swiftui/contentunavailableview
if videos.isEmpty {
    ContentUnavailableView(
        "No Videos",
        systemImage: "video.slash",
        description: Text("Add videos to get started")
    )
}
```

### Pattern 5: 16:9 Aspect Ratio for Thumbnails
**What:** YouTube standard thumbnail dimensions
**When to use:** All video thumbnail displays
**Why:** YouTube thumbnails are 1280x720 (16:9), displaying at different ratios causes distortion
**Example:**
```swift
// Source: https://socialsizes.io/youtube-thumbnail-size/
// YouTube thumbnails: 1280x720 pixels, 16:9 aspect ratio
.frame(width: 100, height: 60)  // Maintains 16:9 at 100pt width
.aspectRatio(16/9, contentMode: .fill)
```

### Anti-Patterns to Avoid
- **LazyVStack for feeds:** List outperforms LazyVStack by 10x for scrolling performance (5.5s vs 52s for 100+ items). LazyVStack maintains full container height, causing height calculation issues during fast scrolling.
- **AsyncImage without URLCache config:** Default AsyncImage has no disk cache, images re-download on scroll. Must configure URLCache.shared manually or use Kingfisher.
- **Custom skeleton animations:** SwiftUI's .redacted() is simpler, respects system accessibility settings, and works with all view types. Custom shimmers add complexity without clear benefit.
- **Eager image loading:** Loading all images at once causes memory explosion. KFImage with .cancelOnDisappear() only loads visible cells.
- **Ignoring iPhone SE performance:** Success criteria requires 60 FPS on iPhone SE. Must profile on real device, simulator gives false confidence.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image disk caching | Custom URLCache wrapper | Kingfisher | Handles cache expiration, memory pressure, image downsampling, request coalescing, and 8+ years of edge case fixes |
| Skeleton loading animation | Custom shimmer views | .redacted(reason: .placeholder) | Built-in, respects accessibility (reduced motion), works with all SwiftUI views, automatically styled |
| Empty state UI | Custom EmptyStateView | ContentUnavailableView (iOS 17+) | System component, automatically localized, adapts to platform (hides images on watchOS), consistent design |
| Thumbnail URL extraction | Client-side YouTube URL parsing | Backend provides thumbnail_url | YouTube URL patterns can change, backend can cache/fallback, iOS shouldn't depend on external URL structure |
| Image loading cancellation | Manual URLSession task tracking | KFImage .cancelOnDisappear() | Handles edge cases (rapid scrolling, view recycling), prevents memory leaks from orphaned tasks |

**Key insight:** Image caching is deceptively complex. Naive solutions cause memory leaks (no eviction policy), slow scrolling (synchronous disk I/O), or wasted bandwidth (no request coalescing when same image requested twice). Kingfisher has solved these problems through 8+ years of production use across thousands of apps.

## Common Pitfalls

### Pitfall 1: Missing Backend Thumbnail URLs
**What goes wrong:** VideoDTO lacks `thumbnailUrl` field, iOS cannot display real thumbnails
**Why it happens:** Current backend VideoDTO schema doesn't include thumbnail URLs, only sourceUrl
**How to avoid:** Add `thumbnail_url` field to backend VideoDTO response before implementing iOS UI
**Warning signs:**
- grep "thumbnailUrl" APIClient.swift returns no matches
- VideoDTO struct has no thumbnail-related property
- Backend API response inspection shows no thumbnail field
**Resolution:** Backend must extract YouTube thumbnail URL using pattern `https://img.youtube.com/vi/<video_id>/maxresdefault.jpg` and add to VideoDTO. For camera roll videos, backend could generate thumbnails server-side or return placeholder URL.

### Pitfall 2: List Performance Assumption Without Profiling
**What goes wrong:** Assuming 60 FPS performance without measuring on iPhone SE
**Why it happens:** Simulator runs on Mac hardware (much faster), doesn't reveal real device bottlenecks
**How to avoid:** Profile on physical iPhone SE with 100+ videos using Xcode Instruments before marking phase complete
**Warning signs:**
- Testing only on simulator or newer devices (iPhone 15+)
- No Instruments profiling session recorded
- Frame rate not measured with actual video thumbnail loading
**Resolution:** Success criteria explicitly requires "60 FPS on iPhone SE". Use Instruments > SwiftUI or Time Profiler, scroll rapidly through 100+ videos, verify frame rate stays above 58-60 FPS.

### Pitfall 3: Memory Explosion from Unoptimized Images
**What goes wrong:** Loading full-resolution YouTube thumbnails (1280x720) causes memory to balloon
**Why it happens:** iOS loads full image into memory even when displaying at 100x60 pts
**How to avoid:** Use Kingfisher's automatic downsampling or configure .resizable() + .aspectRatio()
**Warning signs:**
- Memory usage climbs continuously while scrolling
- App crashes with memory warnings after viewing 50+ videos
- Instruments shows image memory growing unbounded
**Resolution:** Kingfisher automatically downsamples images to display size. Ensure KFImage uses `.resizable()` and `.frame(width:height:)` to hint target size.

### Pitfall 4: Skeleton Loading on Every Scroll
**What goes wrong:** Skeleton state flickers when scrolling back to previously loaded videos
**Why it happens:** Not distinguishing "initial load" from "already have data"
**How to avoid:** Only show skeleton when `isLoading && videos.isEmpty`, not on refresh or pagination
**Warning signs:**
- Videos flash gray placeholders when scrolling up after scrolling down
- Users report "flashing" or "flickering" during normal scroll
- .redacted() modifier always active regardless of data state
**Resolution:** Skeleton should only appear on first launch or after clearing cache. Cached thumbnails + already-loaded data should display immediately.

### Pitfall 5: ContentUnavailableView vs Loading State Confusion
**What goes wrong:** Showing "No Videos" empty state while API is still loading
**Why it happens:** Rendering logic doesn't distinguish "loading" from "loaded but empty"
**How to avoid:** Use three-state logic: loading (skeleton), empty (ContentUnavailableView), populated (List)
**Warning signs:**
- Empty state appears briefly then disappears when videos load
- Users see "Add videos to get started" for a split second on launch
- Confusing UX where content appears to be missing then suddenly loads
**Resolution:**
```swift
if isLoading && videos.isEmpty {
    // Skeleton state
} else if videos.isEmpty {
    ContentUnavailableView(...)  // Only after loading completes
} else {
    List { ... }
}
```

## Code Examples

Verified patterns from official sources:

### Feed with Loading/Empty/Populated States
```swift
// Source: Synthesized from https://sarunw.com/posts/content-unavailable-view-in-swiftui/
// and current VideoFeedView.swift pattern

struct VideoFeedView: View {
    @State private var videos: [VideoDTO] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                // Skeleton loading
                List(0..<5, id: \.self) { _ in
                    VideoFeedSkeletonRow()
                }
                .redacted(reason: .placeholder)
            } else if videos.isEmpty {
                // Empty state (only after loading completes)
                ContentUnavailableView(
                    "No Videos",
                    systemImage: "video.slash",
                    description: Text("Add videos to get started")
                )
            } else {
                // Populated feed
                List {
                    ForEach(videos) { video in
                        NavigationLink(value: video) {
                            VideoFeedRow(video: video)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .task {
            await loadVideos()
        }
    }
}
```

### KFImage in Feed Row
```swift
// Source: https://github.com/onevcat/Kingfisher/wiki/SwiftUI-Support
import Kingfisher

struct VideoFeedRow: View {
    let video: VideoDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail with Kingfisher
            KFImage(URL(string: video.thumbnailUrl ?? ""))
                .placeholder {
                    // Fallback while loading
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                }
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: 100, height: 60)
                .cornerRadius(8)
                .cancelOnDisappear()  // Critical for scroll performance

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(video.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                Text(video.displayDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(video.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }
}
```

### Skeleton Row (Alternative to .redacted())
```swift
// Source: Custom implementation, simpler than https://joshhomann.medium.com/generic-shimmer-loading-skeletons-in-swiftui-26fcd93ccee5
// Note: .redacted() is preferred, this is for reference

struct VideoFeedSkeletonRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 100, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 14)
                    .frame(width: 200)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                    .frame(width: 80)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UITableView (UIKit) | SwiftUI List backed by UICollectionView | iOS 16 (2022) | List gained cell recycling, modern composition layout, matched UIKit performance |
| Custom skeleton animations | .redacted(reason: .placeholder) | iOS 14 (2020) | Single-line skeleton loading, accessibility-aware, system-styled |
| Manual empty state views | ContentUnavailableView | iOS 17 (2023) | Consistent system design, automatic localization, platform adaptation |
| SDWebImage (UIKit) | Kingfisher (Swift-first) | ~2015 | Pure Swift, SwiftUI native support, lighter weight, async/await ready |
| LazyVStack for feeds | List for feeds | iOS 16+ | List outperforms LazyVStack 10x for scrolling, better memory management |

**Deprecated/outdated:**
- **AsyncImage without caching library:** iOS 15 introduced AsyncImage but without disk cache. Community consensus (2024-2026) is to use Kingfisher for production apps.
- **Custom URLSession-based image loaders:** Pre-iOS 15 pattern. AsyncImage + Kingfisher replaced this entirely.
- **LazyVStack for large feeds:** Still valid for custom layouts, but List is now preferred for standard feed UIs due to performance improvements in iOS 16+.

## Open Questions

Things that couldn't be fully resolved:

1. **Backend thumbnail URL implementation timeline**
   - What we know: Backend needs to add `thumbnail_url` field to VideoDTO response
   - What's unclear: Whether backend already extracts YouTube video IDs or needs this added
   - Recommendation: Phase 14 planning must coordinate with backend. iOS can stub with placeholder URLs initially, but feature isn't complete without real thumbnails. Consider backend task as blocking dependency.

2. **Camera roll video thumbnail generation**
   - What we know: YouTube thumbnails follow predictable URL patterns
   - What's unclear: How backend generates thumbnails for camera roll uploads (no external URL)
   - Recommendation: Backend could generate thumbnails server-side using FFmpeg or return placeholder icon for v1.1. Document as future enhancement if complex.

3. **Thumbnail size optimization strategy**
   - What we know: YouTube provides multiple resolutions (default.jpg, mqdefault.jpg, hqdefault.jpg, sddefault.jpg, maxresdefault.jpg)
   - What's unclear: Whether backend should serve maxresdefault.jpg (1280x720) or smaller resolution to save bandwidth
   - Recommendation: Start with maxresdefault.jpg for quality, let Kingfisher downsample on device. Monitor backend bandwidth usage, optimize later if needed. Most thumbnails are <100KB, unlikely bottleneck.

4. **Skeleton loading row count**
   - What we know: Should show skeleton rows during initial load
   - What's unclear: Optimal number of skeleton rows (5? 10? Fill screen?)
   - Recommendation: Show 5-7 skeleton rows (enough to fill iPhone SE screen without scrolling). Research shows consistent row count reduces layout shift.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation - ContentUnavailableView (iOS 17)
- [Kingfisher GitHub](https://github.com/onevcat/Kingfisher) - v8.0 features, SwiftUI support
- [Kingfisher SwiftUI Support Wiki](https://github.com/onevcat/Kingfisher/wiki/SwiftUI-Support) - KFImage patterns, caching
- Current codebase: VideoFeedView.swift (List architecture already correct)

### Secondary (MEDIUM confidence)
- [SwiftUI List vs LazyVStack performance comparison](https://www.strv.com/blog/swiftui-list-vs-lazyvstack) - 10x performance difference verified by multiple sources
- [List or LazyVStack - Choosing the Right Lazy Container](https://fatbobman.com/en/posts/list-or-lazyvstack/) - iOS 16+ architecture changes
- [YouTube Thumbnail Size 2026](https://socialsizes.io/youtube-thumbnail-size/) - 1280x720, 16:9 aspect ratio standard
- [YouTube thumbnail URL pattern](https://mohamed-abdo.medium.com/how-to-retrieve-youtube-video-thumbnails-using-youtube-api-and-direct-urls-adc8114ff318) - maxresdefault.jpg format
- [Redacted View Modifier in SwiftUI](https://www.avanderlee.com/swiftui/redacted-view-modifier/) - Skeleton loading patterns
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps) - 60 FPS profiling techniques

### Tertiary (LOW confidence - flags for validation)
- [Custom Skeleton Loading in SwiftUI](https://medium.com/@thiagorodriguescenturion/stop-using-progressview-custom-skeleton-loading-in-swiftui-83682ca7a13e) - Custom implementation patterns (not recommended, .redacted() preferred)
- [LazyVStack vs List in iOS 18](https://dev.to/thevediwho/lazyvstack-vs-list-in-ios-18-30daysofswift-8fp) - iOS 18 improvements mentioned but not verified with official docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Kingfisher is industry standard (24k+ stars, 8+ years), List architecture already proven in codebase
- Architecture: HIGH - List vs LazyVStack performance verified by multiple sources, ContentUnavailableView is official iOS 17 API
- Pitfalls: HIGH - Backend thumbnail URL gap confirmed by code inspection (VideoDTO has no thumbnailUrl field), performance profiling requirement from success criteria

**Research date:** 2026-01-31
**Valid until:** 2026-02-28 (30 days - stable APIs, SwiftUI patterns change slowly)

**Critical blockers identified:**
1. Backend must add `thumbnail_url` to VideoDTO response (schema change)
2. Must profile on iPhone SE hardware before marking complete (success criteria)

**Research scope covered:**
- Image loading and caching libraries (Kingfisher vs alternatives)
- Feed container performance (List vs LazyVStack)
- Skeleton loading patterns (.redacted() vs custom)
- Empty state UI (ContentUnavailableView)
- Thumbnail sizing and aspect ratios
- Performance profiling techniques
- Backend thumbnail URL patterns for YouTube
