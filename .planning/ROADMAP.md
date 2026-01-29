# Roadmap: Scrollsmith v1.1 UI Polish

## Milestones

- ✅ **v1.0 MVP** - Phases 1-12 (shipped 2026-01-28)
- 🚧 **v1.1 UI Polish** - Phases 13-16 (in progress)

## Overview

v1.1 transforms Scrollsmith from tab-based navigation to a Readwise Reader-inspired sidebar experience. The milestone delivers a central video feed homepage with rich card UI, sidebar navigation (Library, Types, Playbooks, Tags, Trash), embedded YouTube playback, and fixes existing UI bugs. The 4-phase approach builds navigation foundation first, then feed implementation, then sidebar population with bug fixes, and finally summary enhancements.

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-12) - SHIPPED 2026-01-28</summary>

v1.0 delivered the core Scrollsmith experience: video capture (YouTube URLs, camera roll uploads, share sheet), AI-powered summaries (bullets, steps, cards), Playbook organization, habit tracking with streaks, and Pro subscription with Apple Sign In.

Phases 1-12 completed across authentication, video processing, AI summarization, habit tracking, subscription management, and polish.

</details>

## 🚧 v1.1 UI Polish (In Progress)

**Milestone Goal:** Production-grade UI redesign inspired by Readwise Reader — transform Scrollsmith into a polished "second brain for doomscrolling" with sidebar navigation, video feed homepage, and embedded playback.

### Phase 13: Navigation Architecture
**Goal**: Users can navigate via sidebar on iPhone/iPad with automatic layout adaptation
**Depends on**: Phase 12 (v1.0 complete)
**Requirements**: NAV-01, NAV-02
**Success Criteria** (what must be TRUE):
  1. App displays sidebar navigation with Library, Types, Playbooks, Tags, Trash sections
  2. iPhone users see overlay sidebar (sheet/overlay) that slides in from side
  3. iPad users see persistent sidebar in split-view layout
  4. Tapping sidebar items navigates to corresponding detail views without lag
  5. Navigation state persists when rotating iPad or switching between sections
**Plans**: 3 plans

Plans:
- [ ] 13-01-PLAN.md — Navigation foundation (SidebarSection enum + NavigationModel)
- [ ] 13-02-PLAN.md — Navigation shell (SidebarView + RootNavigationView + ContentView wiring)
- [ ] 13-03-PLAN.md — Verify navigation on iPhone and iPad

### Phase 14: Video Feed & Cards
**Goal**: Users see video library as rich feed with cards instead of basic grid
**Depends on**: Phase 13
**Requirements**: FEED-01, FEED-02, FEED-03, FEED-04, FEED-07
**Success Criteria** (what must be TRUE):
  1. Homepage displays central video feed with card-based layout (replaces grid)
  2. Video cards show thumbnail, title, creator/source, and duration estimate
  3. Feed displays skeleton loading states while fetching videos from backend
  4. Feed displays helpful empty state with call-to-action when no videos exist
  5. Scrolling through 100+ videos maintains 60 FPS performance on iPhone SE
  6. Thumbnails load quickly and remain cached when scrolling back up
**Plans**: TBD

Plans:
- [ ] 14-01: TBD

### Phase 15: Sidebar Population & Bug Fixes
**Goal**: Sidebar sections filter video library and existing UI bugs are resolved
**Depends on**: Phase 14
**Requirements**: NAV-03, NAV-04, NAV-05, NAV-06, FEED-05, FEED-06, SUMM-02, SUMM-03
**Success Criteria** (what must be TRUE):
  1. Types section shows YouTube, Camera Roll, Has Habits filters that update feed
  2. Playbooks section lists user's playbooks with video counts that route to filtered views
  3. Tags section shows user's tags with video counts (placeholder for future implementation)
  4. Trash section shows soft-deleted videos users can restore or permanently delete
  5. Users can swipe left on video cards to archive (with haptic feedback)
  6. Users can swipe right on video cards to favorite (with haptic feedback)
  7. View Original and Create Action Points buttons no longer overlap in summary view
  8. Steps/cards panel displays correctly for free tier with Pro upgrade prompt (not blank)
**Plans**: TBD

Plans:
- [ ] 15-01: TBD

### Phase 16: Summary Enhancements & Polish
**Goal**: YouTube videos play inline and summary view provides native video experience
**Depends on**: Phase 15
**Requirements**: SUMM-01
**Success Criteria** (what must be TRUE):
  1. YouTube videos display embedded player above summary content (not just link)
  2. Users can play/pause YouTube videos directly within app without external navigation
  3. Video player respects YouTube TOS (official iframe embed, no background audio)
  4. Camera roll videos continue using existing video player (unchanged)
**Plans**: TBD

Plans:
- [ ] 16-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 13 → 14 → 15 → 16

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-12. v1.0 MVP | v1.0 | All | Complete | 2026-01-28 |
| 13. Navigation Architecture | v1.1 | 0/3 | Ready to execute | - |
| 14. Video Feed & Cards | v1.1 | 0/? | Not started | - |
| 15. Sidebar Population & Bug Fixes | v1.1 | 0/? | Not started | - |
| 16. Summary Enhancements & Polish | v1.1 | 0/? | Not started | - |

---
*Roadmap created: 2026-01-29*
*Milestone v1.1 phases: 13-16*
