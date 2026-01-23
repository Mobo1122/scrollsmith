# Phase 7: Summary Display - Research

**Researched:** 2026-01-23
**Domain:** iOS SwiftUI summary visualization with multi-format display, deep-linking, and ADHD-friendly UI
**Confidence:** HIGH

## Summary

This phase implements iOS UI to display AI-generated summaries in three formats (bullets, steps, cards) with deep-linking to source videos. The research focuses on SwiftUI patterns for multi-format content display, Tinder-style card swiping, platform-specific deep-linking, and ADHD-friendly design principles.

The codebase already uses `@Observable` ViewModels with `@State` (iOS 17+ pattern) and has established patterns for API calls, sheet presentations, and async state management. This phase extends the existing `VideoDTO` to include Pro summary fields and creates new display views.

**Primary recommendation:** Use TabView with `.page` style for simple card swiping, implement custom DragGesture for the Tinder-style step completion cards, and extend VideoDTO to include `summarySteps`/`summaryCards` fields that map to backend JSON structures.

## Standard Stack

The established libraries/tools for this domain:

### Core (Already in Codebase)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI framework | Already used throughout app |
| AVKit | iOS 17+ | Video playback | Apple's standard for inline video players |
| PhotosUI | iOS 17+ | Photos access | Already used for camera roll integration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Observation | iOS 17+ | @Observable macro | Already used for ViewModels |

### No Additional Libraries Needed
The implementation can be achieved entirely with SwiftUI's built-in components:
- `Picker` with `.segmented` style for format switching
- `TabView` with `.page` style for swipeable cards
- `DragGesture` for custom Tinder-style swipe interactions
- `AVPlayer` / `VideoPlayer` for inline camera roll playback
- `UIApplication.shared.open()` for deep-linking to external apps

## Architecture Patterns

### Recommended Project Structure
```
ios/Scrollsmith/
├── Views/
│   └── Summary/
│       ├── SummaryDisplayView.swift      # Main container with format switcher
│       ├── BulletSummaryView.swift       # Bullet point list display
│       ├── StepChecklistView.swift       # Step-by-step with timeline
│       ├── CardStackView.swift           # Tinder-style swipeable cards
│       └── InlineVideoPlayerView.swift   # Camera roll video preview
├── ViewModels/
│   └── SummaryViewModel.swift            # Format state, step completion, card progress
├── Models/
│   └── SummaryModels.swift               # StepItem, CardItem, SummaryFormat enum
└── Services/
    └── DeepLinkService.swift             # URL scheme handling for all platforms
```

### Pattern 1: Format Switching with Segmented Control
**What:** Use Picker with `.segmented` style for Bullets | Steps | Cards switching
**When to use:** Top of SummaryDisplayView to select display format
**Example:**
```swift
// Source: Hacking with Swift - Segmented Controls
enum SummaryFormat: String, CaseIterable {
    case bullets = "Bullets"
    case steps = "Steps"
    case cards = "Cards"
}

struct FormatPicker: View {
    @Binding var selection: SummaryFormat
    let availableFormats: Set<SummaryFormat>
    let isPro: Bool

    var body: some View {
        Picker("Format", selection: $selection) {
            ForEach(SummaryFormat.allCases, id: \.self) { format in
                if availableFormats.contains(format) {
                    Text(format.rawValue)
                        .tag(format)
                } else if !isPro && (format == .steps || format == .cards) {
                    // Pro badge overlay handled separately
                    Text(format.rawValue)
                        .tag(format)
                }
            }
        }
        .pickerStyle(.segmented)
    }
}
```

### Pattern 2: Tinder-Style Card Swiping with DragGesture
**What:** Custom swipeable cards with rotation, threshold detection, and swipe actions
**When to use:** CardStackView for step completion cards
**Example:**
```swift
// Source: swift.mackarous.com - Tinder Swipe Tutorial
struct SwipeableCard: View {
    let card: CardItem
    @Binding var offset: CGSize
    let onSwipeRight: () -> Void  // Complete
    let onSwipeLeft: () -> Void   // Skip

    private let threshold: CGFloat = 120

    var body: some View {
        cardContent
            .offset(x: offset.width)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { value in
                        if offset.width > threshold {
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset.width = 300
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipeRight()
                            }
                        } else if offset.width < -threshold {
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset.width = -300
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipeLeft()
                            }
                        } else {
                            withAnimation(.interactiveSpring()) {
                                offset = .zero
                            }
                        }
                    }
            )
    }
}
```

### Pattern 3: TabView Paging for Simple Card Navigation
**What:** TabView with `.page` style for non-interactive card browsing
**When to use:** Alternative to Tinder-style when just viewing cards without actions
**Example:**
```swift
// Source: Hacking with Swift - TabView Paging
struct CardPagerView: View {
    let cards: [CardItem]
    @State private var currentIndex = 0

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                CardView(card: card)
                    .tag(index)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
```

### Pattern 4: @Observable ViewModel (Codebase Standard)
**What:** Use @Observable macro with @State in views
**When to use:** All new ViewModels following existing codebase pattern
**Example:**
```swift
// Source: Codebase - PlaybookViewModel.swift, SearchViewModel.swift
@Observable
final class SummaryViewModel {
    var currentFormat: SummaryFormat = .bullets
    var stepCompletionState: [Int: Bool] = [:]  // step_number: isComplete
    var cardProgress: Int = 0
    var isLoading = false
    var error: String?

    // Persists step completion per video
    func toggleStepCompletion(_ stepNumber: Int, for videoId: UUID) {
        stepCompletionState[stepNumber, default: false].toggle()
        // Persist to UserDefaults or backend
    }
}
```

### Anti-Patterns to Avoid
- **Using @StateObject with @Observable:** Use `@State private var viewModel = SummaryViewModel()` instead
- **Hardcoded URL schemes:** Create a DeepLinkService that handles scheme variations gracefully
- **Blocking main thread for video loading:** Always use async patterns for PHAsset access
- **Tight coupling to specific summary format:** Design views to handle missing/partial data gracefully

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Paging indicator dots | Custom view with circles | `.indexViewStyle(.page(backgroundDisplayMode: .always))` | Built-in handles visibility, positioning, animation |
| Spring animation for card snap-back | Manual easing calculations | `.animation(.interactiveSpring())` | Apple's tuned for touch interaction |
| Segmented control styling | Custom HStack with buttons | `Picker` with `.pickerStyle(.segmented)` | Native appearance, accessibility built-in |
| Video playback controls | Custom play/pause buttons | `VideoPlayer` from AVKit | Standard controls, PiP support, accessibility |
| Flow layout for tags | Manual wrapping calculations | Custom `Layout` protocol (already in codebase) | `FlowLayout` exists in VideoTagEditorView.swift |

**Key insight:** SwiftUI's TabView with `.page` style handles most swipeable card needs. Only use custom DragGesture when you need directional actions (swipe right = complete, swipe left = skip).

## Common Pitfalls

### Pitfall 1: YouTube Deep Link Timestamp Format
**What goes wrong:** Using decimal timestamps (1.5m) or wrong parameter format
**Why it happens:** YouTube has strict requirements for timestamp parameters
**How to avoid:** Always use integer-based formats: `&t=90` (seconds) or `&t=1m30s`
**Warning signs:** Timestamp ignored, video starts from beginning

### Pitfall 2: Photos App Deep Link Limitations
**What goes wrong:** Attempting to deep-link directly to a specific PHAsset in Photos app
**Why it happens:** iOS doesn't provide a reliable public URL scheme for this
**How to avoid:** Use inline `VideoPlayer` for camera roll content instead of trying to open Photos app to specific asset
**Warning signs:** Photos app opens but doesn't navigate to the video

### Pitfall 3: Card Stack Simultaneous Drag
**What goes wrong:** All cards in stack respond to drag gesture simultaneously
**Why it happens:** DragGesture applied to container instead of individual cards
**How to avoid:** Track `draggingCard` state, only apply gesture to top card or conditionally apply offset
**Warning signs:** Entire stack moves together instead of just top card

### Pitfall 4: Missing Pro Tier Check Before Format Switch
**What goes wrong:** Free user switches to Steps/Cards format and sees empty or error state
**Why it happens:** Format picker allows selection without gating check
**How to avoid:** Either disable segments for non-Pro users with badge, or show paywall sheet immediately on tap
**Warning signs:** Empty summary view or API error for free users

### Pitfall 5: TabView Page Style Not Working on macOS
**What goes wrong:** App crashes or shows wrong UI on Catalyst/macOS
**Why it happens:** `.page` style only works on iOS, tvOS, watchOS
**How to avoid:** This is iOS-only app, but if future macOS support: use platform checks
**Warning signs:** Build errors or runtime crashes on macOS

## Code Examples

Verified patterns from official sources and codebase analysis:

### Deep Link URL Construction
```swift
// Source: Research findings + YouTube documentation
struct DeepLinkService {
    enum Platform {
        case youtube(videoId: String, timestampSeconds: Int?)
        case tiktok(videoUrl: String)
        case instagram(postUrl: String)
        case cameraRoll(localIdentifier: String)
    }

    func openURL(for platform: Platform) {
        let url: URL?

        switch platform {
        case .youtube(let videoId, let timestamp):
            // YouTube app scheme with timestamp
            var urlString = "https://www.youtube.com/watch?v=\(videoId)"
            if let t = timestamp {
                urlString += "&t=\(t)"  // Seconds format
            }
            url = URL(string: urlString)

        case .tiktok(let videoUrl):
            // TikTok: just open the web URL, app will intercept via universal links
            url = URL(string: videoUrl)

        case .instagram(let postUrl):
            // Instagram: web URL, app intercepts via universal links
            url = URL(string: postUrl)

        case .cameraRoll:
            // Don't try to deep link - use inline player instead
            url = nil
        }

        if let url {
            UIApplication.shared.open(url)
        }
    }
}
```

### Extended VideoDTO with Summary Fields
```swift
// Source: Backend schemas + existing VideoDTO pattern
struct VideoDTO: Codable, Identifiable {
    let id: UUID
    let sourceUrl: String?
    let summaryBullets: String?
    let summarySteps: String?  // NEW: JSON string of StepChecklist
    let summaryCards: String?  // NEW: JSON string of CardsSummary
    let tags: [String]?
    let createdAt: Date

    // Parsed summary helpers
    var parsedBullets: [String]? {
        guard let json = summaryBullets else { return nil }
        // Parse JSON array of strings
        return try? JSONDecoder().decode([String].self, from: Data(json.utf8))
    }

    var parsedSteps: StepChecklist? {
        guard let json = summarySteps else { return nil }
        return try? JSONDecoder().decode(StepChecklist.self, from: Data(json.utf8))
    }

    var parsedCards: CardsSummary? {
        guard let json = summaryCards else { return nil }
        return try? JSONDecoder().decode(CardsSummary.self, from: Data(json.utf8))
    }
}

// Mirror backend schemas
struct StepChecklist: Codable {
    let title: String
    let steps: [StepItem]
    let estimatedDurationMinutes: Int?
}

struct StepItem: Codable, Identifiable {
    let stepNumber: Int
    let instruction: String
    let timestampSeconds: Int?

    var id: Int { stepNumber }
}

struct CardsSummary: Codable {
    let cards: [CardItem]
}

struct CardItem: Codable, Identifiable {
    let title: String
    let content: String
    let category: CardCategory

    var id: String { title }  // Or use index
}

enum CardCategory: String, Codable {
    case tip, warning, insight, action
}
```

### Inline Camera Roll Video Player
```swift
// Source: AVKit documentation + PhotosUI patterns
import AVKit
import PhotosUI

struct InlineVideoPlayerView: View {
    let localIdentifier: String

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if let error {
                ContentUnavailableView(
                    "Video Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .task {
            await loadVideo()
        }
    }

    private func loadVideo() async {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        )

        guard let asset = fetchResult.firstObject else {
            error = "Video not found in library"
            isLoading = false
            return
        }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: options
        ) { avAsset, _, _ in
            DispatchQueue.main.async {
                if let urlAsset = avAsset as? AVURLAsset {
                    self.player = AVPlayer(url: urlAsset.url)
                } else {
                    self.error = "Could not load video"
                }
                self.isLoading = false
            }
        }
    }
}
```

### Step Completion Persistence
```swift
// Source: Codebase patterns + UserDefaults best practices
@Observable
final class SummaryViewModel {
    private let userDefaults = UserDefaults.standard

    var stepCompletionState: [Int: Bool] = [:]

    func loadStepCompletion(for videoId: UUID) {
        let key = "stepCompletion_\(videoId.uuidString)"
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Int: Bool].self, from: data) {
            stepCompletionState = decoded
        }
    }

    func toggleStepCompletion(_ stepNumber: Int, for videoId: UUID) {
        stepCompletionState[stepNumber, default: false].toggle()
        saveStepCompletion(for: videoId)
    }

    private func saveStepCompletion(for videoId: UUID) {
        let key = "stepCompletion_\(videoId.uuidString)"
        if let data = try? JSONEncoder().encode(stepCompletionState) {
            userDefaults.set(data, forKey: key)
        }
    }
}
```

## ADHD-Friendly Design Patterns

Based on 2026 neurodiverse UX research:

### Typography & Hierarchy
| Principle | Implementation |
|-----------|---------------|
| Clean fonts | Use SF Pro (system default), avoid decorative fonts |
| Adequate spacing | `lineSpacing(4)` minimum, generous padding |
| Clear hierarchy | Use `.title`, `.headline`, `.body` with distinct sizes |
| High contrast | Avoid low-contrast color combinations |

### Visual Clarity
| Principle | Implementation |
|-----------|---------------|
| Minimal distractions | No auto-playing animations, calm color palette |
| Hick's Law | Maximum 3 format options, clear primary action |
| Visual progress | Timeline dots for steps, card stack hint for cards |
| Predictable layout | Consistent positioning across all formats |

### Card-Specific UX (from CONTEXT.md)
| Feature | ADHD Benefit |
|---------|-------------|
| Large tap target (entire card) | No hunting for small buttons |
| Swipe labels that appear on drag | Clear feedback about action meaning |
| Toast confirmation after action | Immediate acknowledgment of progress |
| Gentle snap-back animation | Forgiving if accidental swipe |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ObservableObject + @Published | @Observable macro | iOS 17 (2023) | Less boilerplate, automatic view updates |
| @StateObject for ViewModels | @State with @Observable | iOS 17 | Simpler mental model, no ownership confusion |
| Custom paging implementations | TabView + .page style | iOS 14+ | Built-in, reliable paging with indicators |
| UIViewRepresentable for video | Native VideoPlayer | iOS 14+ | SwiftUI-native video playback |

**Note:** The codebase correctly uses iOS 17+ patterns with `@Observable` ViewModels.

## Open Questions

Things that couldn't be fully resolved:

1. **Photos App Deep Link to Specific Asset**
   - What we know: iOS has `photos:` URL scheme but navigation to specific asset is unreliable
   - What's unclear: Whether any private/undocumented API reliably works
   - Recommendation: Use inline VideoPlayer for camera roll content per CONTEXT.md decision

2. **TikTok/Instagram App URL Scheme Stability**
   - What we know: These apps change their URL schemes periodically
   - What's unclear: Current exact schemes that reliably open specific videos
   - Recommendation: Use HTTPS URLs and rely on universal links/app clips to intercept

3. **Step Completion Backend Sync**
   - What we know: CONTEXT.md says "step completion state persists per video"
   - What's unclear: Should this sync to backend or stay local?
   - Recommendation: Start with UserDefaults (local), add backend sync in Phase 9/10 if needed

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `VideoDTO`, `PlaybookViewModel`, `SearchViewModel`, `VideoTagEditorView`
- Backend schemas: `/backend/app/schemas/summary.py` - StepChecklist, CardsSummary structures
- Apple Developer Documentation: TabView, Picker, AVKit, PhotosUI

### Secondary (MEDIUM confidence)
- [Hacking with Swift - TabView Paging](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-scrolling-pages-of-content-using-tabviewstyle) - Verified patterns
- [Hacking with Swift - Segmented Controls](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-segmented-control-and-read-values-from-it) - Verified patterns
- [Swift Mackarous - Tinder Swipe](https://swift.mackarous.com/posts/2023/02/tinder-swipe/) - DragGesture patterns
- [Medium - @Observable in iOS 17](https://medium.com/@sayefeddineh/understanding-observable-in-ios-17-the-future-of-swiftui-state-management-9085fe9c3ed8) - State management patterns

### Tertiary (LOW confidence - for validation)
- [SwiftLee - Deep Link Handling](https://www.avanderlee.com/swiftui/deeplink-url-handling/) - General patterns
- [YouTube Timestamp Link Generators](https://tuberanker.com/blog/youtube-timestamp-link) - URL format verification
- [ADHD UX Design Patterns](https://din-studio.com/ui-ux-for-adhd-designing-interfaces-that-actually-help-students/) - Design principles

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing codebase patterns
- Architecture: HIGH - Follows established ViewModels and Views structure
- Deep linking: MEDIUM - YouTube verified, other platforms may vary
- ADHD patterns: MEDIUM - Best practices from multiple sources
- Swipe gestures: HIGH - Well-documented SwiftUI patterns

**Research date:** 2026-01-23
**Valid until:** 2026-02-23 (30 days - stable patterns)
