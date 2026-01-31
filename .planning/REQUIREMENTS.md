# Requirements: Scrollsmith v1.1 UI Polish

**Defined:** 2026-01-29
**Core Value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits

## v1.1 Requirements

Requirements for UI polish milestone. Each maps to roadmap phases.

### Navigation

- [x] **NAV-01**: App uses sidebar navigation with sections: Library, Playbooks, Tags, Trash *(Types removed per user feedback)*
- [x] **NAV-02**: Sidebar adapts between iPhone (NavigationSplitView standard) and iPad (persistent sidebar)
- [ ] **NAV-03**: Types section shows filters: YouTube, Camera Roll, Has Habits
- [ ] **NAV-04**: Playbooks section shows user's playbooks with video counts
- [ ] **NAV-05**: Tags section shows user's tags with video counts
- [ ] **NAV-06**: Trash section shows soft-deleted videos

### Video Feed

- [ ] **FEED-01**: Homepage shows central video feed (replaces current grid)
- [ ] **FEED-02**: Video cards display thumbnail, title, creator/source, duration
- [ ] **FEED-03**: Feed shows skeleton loading states while fetching videos
- [ ] **FEED-04**: Feed shows empty state when no videos exist
- [ ] **FEED-05**: User can swipe left on video card to archive
- [ ] **FEED-06**: User can swipe right on video card to favorite
- [ ] **FEED-07**: Thumbnails are cached to prevent re-downloading on scroll

### Summary View

- [ ] **SUMM-01**: YouTube videos display embedded player above summary content
- [ ] **SUMM-02**: View Original and Create Action Points buttons do not overlap
- [ ] **SUMM-03**: Steps/cards panel displays correctly for free tier (with Pro upgrade prompt)

## Future Requirements

Deferred to later milestones. Tracked but not in v1.1 roadmap.

### Navigation Enhancements

- **NAV-F1**: Badge counts on sidebar items showing unread/new videos
- **NAV-F2**: Users can customize sidebar section ordering
- **NAV-F3**: Users can pin favorite playbooks to top of sidebar

### Feed Enhancements

- **FEED-F1**: Pull-to-refresh to sync videos from backend
- **FEED-F2**: TikTok-style vertical swipe feed for quick review
- **FEED-F3**: Batch selection mode for bulk actions

### Polish

- **POLI-F1**: Haptic feedback on button presses and swipe gestures
- **POLI-F2**: Smooth spring animations on navigation transitions
- **POLI-F3**: Customizable accent colors

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Content type expansion (articles, podcasts) | v1.1 is UI polish, not feature expansion |
| Social/collaborative features | Single-user experience per PROJECT.md |
| Custom themes beyond dark/light | Low value, high complexity |
| Offline video playback | Storage concerns, out of core value |
| Web companion app | Mobile-only per PROJECT.md |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| NAV-01 | Phase 13 | Complete |
| NAV-02 | Phase 13 | Complete |
| NAV-03 | Phase 15 | Pending |
| NAV-04 | Phase 15 | Pending |
| NAV-05 | Phase 15 | Pending |
| NAV-06 | Phase 15 | Pending |
| FEED-01 | Phase 14 | Pending |
| FEED-02 | Phase 14 | Pending |
| FEED-03 | Phase 14 | Pending |
| FEED-04 | Phase 14 | Pending |
| FEED-05 | Phase 15 | Pending |
| FEED-06 | Phase 15 | Pending |
| FEED-07 | Phase 14 | Pending |
| SUMM-01 | Phase 16 | Pending |
| SUMM-02 | Phase 15 | Pending |
| SUMM-03 | Phase 15 | Pending |

**Coverage:**
- v1.1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

**Phase Distribution:**
- Phase 13 (Navigation Architecture): 2 requirements
- Phase 14 (Video Feed & Cards): 5 requirements
- Phase 15 (Sidebar Population & Bug Fixes): 8 requirements
- Phase 16 (Summary Enhancements & Polish): 1 requirement

---
*Requirements defined: 2026-01-29*
*Last updated: 2026-01-31 with Phase 13 completion*
