# Feature Landscape: Read-It-Later UI/UX Patterns

**Domain:** Read-it-later / Content Curation Apps (Readwise Reader, Pocket, Instapaper)
**Researched:** 2026-01-29
**Overall confidence:** MEDIUM-HIGH

## Executive Summary

Read-it-later apps like Readwise Reader achieve production-grade feel through a combination of intuitive navigation, sophisticated triage workflows, and delightful micro-interactions. The key differentiators are not flashy features but rather thoughtful patterns: customizable sidebar navigation, gesture-based triage (inspired by Superhuman's email workflows), progressive disclosure to reduce cognitive load, and typography customization for extended reading sessions.

For Scrollsmith v1.1, adapting these patterns means creating a polished "second brain for doomscrolling" experience where video content feels as organized and accessible as text-based read-it-later apps. The focus should be on table-stakes UI polish (skeleton screens, haptic feedback, pull-to-refresh) combined with differentiating features (swipe-based triage, content cards with visual hierarchy, customizable views).

## Table Stakes

Features users expect from production-grade content curation apps. Missing these = app feels incomplete or unprofessional.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Sidebar Navigation** | Industry standard in Readwise Reader, enables quick context switching | Medium | Left sidebar with fixed sections (Home, Library, Inbox) and customizable views. Drag-to-reorder, pin/unpin views. |
| **Content Cards** | Preferred over list view for heterogeneous content (videos of varying lengths, sources) | Low | "One card, one concept" - show thumbnail, title, source, duration, status. Generous whitespace between cards. |
| **Pull-to-Refresh** | Universal mobile gesture for updating content | Low | Visual threshold indicator, subtle haptic feedback at trigger point, circular spinner during refresh. |
| **Skeleton Screens** | Modern loading pattern (used by LinkedIn, YouTube, Facebook) for perceived performance | Medium | Show wireframe layout while content loads. Subtle shimmer animation. Use for <10s load times. |
| **Dark Mode** | Expected for reading apps to reduce eye strain | Low | System theme detection with manual override. Affects all screens including video playback UI. |
| **Empty States** | Major onboarding opportunity for first-time users | Low | Heading + Motivation + Clear CTA. Example: "No videos yet" → "Capture your first video to build your second brain" → [Capture Video button]. |
| **Search + Filters** | Essential for content discovery as library grows | Medium | Real-time search with <200ms response. Tag filters, date filters, playbook filters. Interactive filtering (instant results). |
| **Swipe Gestures** | Mobile-native interaction pattern for quick actions | Medium | Left/right swipes on cards for triage. Short swipe = preview action, long swipe = execute. Customizable swipe actions in settings. |
| **Badge Counts** | Keeps users engaged with unread/new content | Low | Show count on Inbox view in sidebar. Keep counts low (research shows 10+ discourages engagement). Clear badge when viewed. |
| **Visual Hierarchy** | Guides attention to most important elements | Low | Card hierarchy: thumbnail (largest), title (bold), metadata (secondary color, smaller font). Use 1-2 font families max. |
| **Haptic Feedback** | Makes interactions feel tangible and responsive | Low | Light haptic on swipe threshold, medium on card archive, heavy on delete. Allow users to disable in settings. |
| **Typography Customization** | Expected for reading apps (body text 15-20px) | Low | Font size adjustment (for summaries/habits). Medium font weight for readability. 45-75 characters per line ideal. |

## Differentiators

Features that set the product apart from basic video libraries. Not expected, but highly valued when present.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **TikTok-Inspired Feed UI** | Readwise Reader's "Feed" for quick triage - swipe up to advance, down to reverse, tap to read | High | Vertical full-screen cards. Swipe up marks as "seen". Addictive game-like triage workflow. Could apply to Inbox or new captures. |
| **Customizable Sidebar Views** | Power user feature - create filtered views (e.g., "Unwatched", "This Week", "Productivity Videos") and pin to sidebar | Medium | Uses tag/playbook/date filters. Drag-to-reorder pinned views. Inspired by Readwise's filtered views system. |
| **Content Status Badges** | Visual indicator on cards showing Inbox/Later/Archive status + watch progress | Low | Small colored dot or pill on card. Green = new, Yellow = in progress, Gray = archived. Reduces cognitive load. |
| **Long-Form Reading View** | Readwise's minimal UI for extended reading - hide action bars, show only progress + appearance settings | Medium | For watching videos or reading summaries. Minimal chrome, focus on content. Auto-enabled for longer content. |
| **Paged Scroll Navigation** | Vertical pagination with tap-to-advance (tap left/right margins to flip) | Medium | Alternative to continuous scroll. Preserves swipe gestures while enabling discrete sections (summary cards already use this concept). |
| **Annotation System** | Highlight moments in video (timecodes) with notes - syncs to Readwise-style "highlights" | High | Right-margin marginalia style. Tap video timestamp to add note. Export to Markdown/Notion. Differentiates from basic video apps. |
| **Daily Digest View** | Curated presentation of "Saved for Later" + new content in scrollable triage format | Medium | Surfaces content user intended to watch. Game-like workflow to clear backlog. Reduces decision fatigue. |
| **Triage Keyboard Shortcuts** | Power user feature - Archive (A), Later (L), Delete (D) for quick desktop workflows | Low | Web/iPad only. Follows Readwise/Superhuman patterns. Shows keyboard hints on hover. |
| **E-ink Mode** | Auto-detect e-ink devices and optimize display (high contrast, no animations) | Low-Medium | Niche but shows attention to detail. Useful for iPad users with Paper-like screen protectors. |
| **Progress Indicators** | Show watch progress on video cards (e.g., "45% watched") | Low | Visual progress bar at bottom of card thumbnail. Helps users resume where they left off. |

## Anti-Features

Features to explicitly NOT build. Common mistakes or clutter in content apps.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Hamburger Menu** | Hides navigation, requires extra tap. Acceptable on mobile but avoid on tablet/web where space allows sidebar. | Use persistent left sidebar on tablet/web. Only collapse to hamburger on smallest iPhone screens. |
| **Auto-Play Previews** | Annoying in feed/list views, drains battery, uses data | Show static thumbnail. Let user tap to play. Exception: Preview on long-press could work as progressive disclosure. |
| **Nested Folder Hierarchies** | Cognitive overhead. Read-it-later apps use flat tags + filtered views instead. | Flat playbooks + tags. Create filtered views for complex organization (e.g., "Work Videos from Last Week"). |
| **Social Features** | Scope creep. Sharing/following adds complexity without clear value for "second brain" use case. | Focus on individual workflow. Allow export/share of individual videos, not social graph. |
| **Complicated Onboarding** | Multi-screen tours that users skip. Research shows users want fast access. | Use empty states with single clear CTA. Progressive disclosure - show features when relevant, not upfront. |
| **Generic Loading Spinners** | Feels dated vs. skeleton screens. Doesn't reduce perceived wait time. | Use skeleton screens with subtle shimmer animation. Show layout structure while loading. |
| **Notification Overload** | Badge counts >10 discourage engagement. Push notifications for every action = user disables. | Batch notifications. Use badge for Inbox count only. Let users configure notification preferences. |
| **Infinite Scroll Without Pagination** | Difficult to return to specific position, no sense of progress | Hybrid: Load more as user scrolls but show "showing 1-20 of 50" indicator. Or use vertical pagination. |
| **Non-Standard Gestures** | Users expect iOS/Android native patterns. Custom gestures require learning. | Follow platform guidelines: swipe-from-left for back on iOS, respect Android gesture navigation zones. |
| **"Busy" Card Design** | Too many elements on cards (tags, buttons, metadata) = visual clutter | Minimal cards: Thumbnail, title, source, duration. Show additional metadata on tap/expand. |

## Feature Dependencies

```
Navigation Foundation
├─ Sidebar Navigation (required first)
│  ├─ Badge Counts (depends on triage statuses)
│  └─ Customizable Views (depends on filter system)
│
├─ Content Cards (required first)
│  ├─ Skeleton Screens (loading state for cards)
│  ├─ Status Badges (visual indicator on cards)
│  └─ Progress Indicators (watch progress on cards)
│
└─ Search + Filters (enables many features)
   ├─ Customizable Sidebar Views (powered by filters)
   └─ Daily Digest View (uses saved filters)

Triage Workflow
├─ Swipe Gestures (core interaction)
│  ├─ Haptic Feedback (enhances gestures)
│  └─ TikTok-Inspired Feed (advanced gesture UI)
│
└─ Content Status System (Inbox/Later/Archive)
   ├─ Badge Counts (shows unread counts)
   └─ Daily Digest View (surfaces Later content)

Reading/Viewing Experience
├─ Typography Customization (base readability)
├─ Dark Mode (base accessibility)
└─ Long-Form Reading View (advanced minimal UI)
   └─ Paged Scroll Navigation (optional alternative)
```

## MVP Recommendation

For Scrollsmith v1.1 to feel production-grade with Readwise-inspired polish:

### Phase 1: Foundation (Must Have)
1. **Sidebar Navigation** - Fixed sections (Home, Inbox, Library, Settings) with customizable pinned views
2. **Content Cards** - Clean card design with thumbnail, title, source, duration, generous whitespace
3. **Skeleton Screens** - For card loading states (professional loading experience)
4. **Dark Mode** - System detection with manual override
5. **Empty States** - Onboarding for first-time users (Heading + Motivation + CTA)
6. **Pull-to-Refresh** - Standard gesture for refreshing Inbox/Library

### Phase 2: Triage Excellence (Differentiator)
1. **Swipe Gestures** - Left/right swipe on cards for Archive/Later/Delete
2. **Content Status System** - Inbox/Later/Archive with badges on cards
3. **Haptic Feedback** - Subtle tactile responses for gestures
4. **Badge Counts** - Show unread count on Inbox sidebar item
5. **Customizable Swipe Actions** - Settings to configure short/long swipe behaviors

### Phase 3: Power User Features (If Time Allows)
1. **Search + Filters** - Real-time search with tag/playbook/date filters
2. **Customizable Sidebar Views** - Create and pin filtered views
3. **Progress Indicators** - Show watch progress on video cards
4. **Daily Digest View** - Game-like triage for "Later" queue
5. **TikTok-Inspired Feed** - Vertical full-screen triage (experimental)

### Defer to Post-v1.1
- Annotation system (high complexity, niche use case)
- E-ink mode (very niche)
- Triage keyboard shortcuts (desktop/web only)
- Long-form reading view (nice-to-have, not critical for v1.1)
- Paged scroll navigation (experimental, unclear value)

## Platform-Specific Considerations

### iOS (Primary Platform for Scrollsmith)

**Leverage iOS Patterns:**
- Swipe-from-left for back navigation (system gesture)
- System haptics (UIImpactFeedbackGenerator - light, medium, heavy)
- Dynamic Type support for accessibility
- SF Symbols for icons (native look and feel)
- Native search bar (UISearchController) for familiarity

**Avoid iOS Pitfalls:**
- Don't conflict with system gestures (swipe-from-edge for back)
- Respect safe area insets (notch, Dynamic Island)
- Support both light and dark mode (required for modern iOS apps)
- Test haptics on actual devices (Simulator doesn't support haptics)

### Design System Integration

Scrollsmith already has a design system (theme colors, components). Map read-it-later patterns to existing system:

- **Cards:** Extend existing card components (summary cards) to video library cards
- **Sidebar:** New component but use existing theme colors/spacing
- **Swipe Actions:** Use theme accent colors for action backgrounds
- **Typography:** Leverage existing font choices, add size customization

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Table Stakes Features | HIGH | Well-established patterns from Readwise Reader, Pocket, Instapaper. Verified via official docs and multiple sources. |
| Differentiators | MEDIUM-HIGH | Readwise Reader's TikTok feed and triage patterns verified. Some features (annotations, paged scroll) are newer, less documented. |
| Anti-Features | MEDIUM | Based on general UX best practices and common mistakes. Some are opinionated (e.g., avoiding social features) based on Scrollsmith's "second brain" positioning. |
| iOS Implementation | HIGH | Apple's design guidelines and haptics documentation are authoritative and current. |
| Complexity Estimates | MEDIUM | Based on general iOS development knowledge. Actual complexity depends on existing Scrollsmith codebase. |

## Gaps to Address

### Areas Needing Further Investigation
1. **Video-Specific Patterns:** Research focused on text-based read-it-later apps. Video content may need adapted patterns (e.g., thumbnail quality, duration indicators, preview on long-press).
2. **Performance at Scale:** How do these apps handle 1000+ items? Lazy loading strategies, pagination limits, search optimization.
3. **Accessibility:** Research touched on Dark Mode and Dynamic Type but didn't deeply investigate VoiceOver, screen reader support, or motor impairment considerations for gestures.
4. **Analytics Integration:** What metrics do read-it-later apps track? (e.g., time-to-triage, completion rates, search usage) - not covered in research.

### Low Confidence Items Flagged
- **TikTok-Inspired Feed:** Mentioned in Readwise changelog but limited details on implementation. May need prototyping to validate for video content.
- **E-ink Mode:** Niche feature, unclear ROI for Scrollsmith's user base.
- **Paged Scroll Navigation:** Readwise implemented vertical pagination but reasoning is text-focused (highlighting across pages). Value for video content unclear.

## Sources

### Readwise Reader Patterns
- [Readwise & Reader Changelog](https://docs.readwise.io/changelog)
- [Navigation - Readwise Docs](https://docs.readwise.io/reader/docs/faqs/navigation)
- [Getting Started with Reader](https://blog.readwise.io/p/bf87944f-b0fe-4f08-a461-f75ab8aded6a/)
- [Appearance - Readwise Docs](https://docs.readwise.io/reader/docs/faqs/appearance)
- [What is Readwise Reader?](https://docs.readwise.io/reader/docs)

### General UX Best Practices (2026)
- [Top UI UX Design Best Practices for 2026](https://uidesignz.com/blogs/ui-ux-design-best-practices)
- [11 UI Design Best Practices for UX Designers (2026 Guide)](https://uxplaybook.org/articles/ui-fundamentals-best-practices-for-ux-designers)
- [17 UX/UI Trends for 2026](https://userguiding.com/blog/ux-ui-trends)

### Card Design Patterns
- [Cards design pattern](https://ui-patterns.com/patterns/cards)
- [Card UI Design: Best practices, Design variants & Examples](https://mobbin.com/glossary/card)
- [Lists vs Cards](https://medium.com/tygodesign/choosing-lists-or-cards-2c9a47773edc)

### Mobile Gestures & Interactions
- [Gesture Navigation in Mobile Apps: Best Practices](https://www.sidekickinteractive.com/designing-your-app/gesture-navigation-in-mobile-apps-best-practices/)
- [Pull to refresh design pattern](https://ui-patterns.com/patterns/pull-to-refresh)
- [Pull to Refresh UI Pattern](https://uxplanet.org/pull-to-refresh-ui-pattern-42a85f671cdf)

### iOS Haptics
- [Haptic Feedback in iOS: A Comprehensive Guide](https://medium.com/@mi9nxi/haptic-feedback-in-ios-a-comprehensive-guide-6c491a5f22cb)
- [2025 Guide to Haptics: Enhancing Mobile UX with Tactile Feedback](https://saropa-contacts.medium.com/2025-guide-to-haptics-enhancing-mobile-ux-with-tactile-feedback-676dd5937774)
- [Practice audio haptic design - WWDC21](https://developer.apple.com/videos/play/wwdc2021/10278/)

### Loading States & Skeletons
- [Skeleton Screens 101](https://www.nngroup.com/articles/skeleton-screens/)
- [Skeleton loading screen design — How to improve perceived performance](https://blog.logrocket.com/ux-design/skeleton-loading-screen-design/)

### Empty States
- [Onboarding UX Patterns | Empty States](https://www.useronboard.com/onboarding-ux-patterns/empty-states/)
- [Designing the Overlooked Empty States – UX Best Practices](https://www.uxpin.com/studio/blog/ux-best-practices-designing-the-overlooked-empty-states/)

### Progressive Disclosure
- [Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/)
- [Design Patterns: Progressive Disclosure for Mobile Apps](https://uxplanet.org/design-patterns-progressive-disclosure-for-mobile-apps-f41001a293ba)

### Search & Filters
- [Getting filters right: UX/UI design patterns and best practices](https://blog.logrocket.com/ux-design/filtering-ux-ui-design-patterns-best-practices/)
- [15 Filter UI Patterns That Actually Work in 2025](https://bricxlabs.com/blogs/universal-search-and-filters-ui)

### Badge Notifications
- [iOS App Notification Badges Best Practices](https://www.willowtreeapps.com/craft/best-practices-for-driving-engagement-with-ios-app-notification-badges)
- [What Are App Icon Badges?](https://reteno.com/blog/what-are-app-icon-badges-definition-tips-for-mobile-marketing)

### Typography
- [Mobile App Typography: UX Design Guide](https://createbytes.com/insights/Typography-rules-for-mobile-application)
- [What are Apple's guidelines on typography for iOS apps?](https://median.co/blog/apples-ui-dos-and-donts-typography)
