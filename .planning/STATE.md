# State: Scrollsmith

**Last Updated:** 2026-01-31

## Project Reference

See: [.planning/PROJECT.md](.planning/PROJECT.md) (updated 2026-01-29)

**Core value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits

**Current focus:** Phase 14 - Video Feed & Cards

## Current Position

**Milestone:** v1.1 UI Polish
Phase: 14 of 16 (Video Feed & Cards)
Plan: 1 of 3 in current phase
Status: In progress
Last activity: 2026-01-31 — Completed 14-01-PLAN.md (Backend Thumbnail URL Support)

Progress: [████████░░░░░░░░░░░░] 78% (v1.0 complete, v1.1 plan 3 done)

## Performance Metrics

**Velocity:**
- v1.0 (Phases 1-12): Complete (70 plans)
- v1.1 (Phases 13-16): 3 plans completed
- Total plans completed: 73 (70 from v1.0 + 3 from v1.1)
- Average duration: 19 min (v1.1 only)

**By Phase (v1.1):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 13. Navigation Architecture | 2/3 | 52 min | 26 min |
| 14. Video Feed & Cards | 1/3 | 4 min | 4 min |
| 15. Sidebar Population & Bug Fixes | 0/? | - | - |
| 16. Summary Enhancements & Polish | 0/? | - | - |

**Recent Trend:**
- 13-01: 5 min (navigation foundation - SidebarSection + NavigationModel)
- 13-02: 47 min (navigation wiring - SidebarView + RootNavigationView)
- 14-01: 4 min (backend thumbnail URL support - API schema + YouTube extraction)

## Accumulated Context

### Decisions

Recent decisions affecting v1.1 work:

- v1.0: SwiftUI native architecture provides foundation for v1.1 redesign
- v1.0: SwiftData + AsyncImage patterns will extend to feed implementation
- v1.1: 4-phase structure prioritizes navigation foundation before feed features (per research)
- v1.1: NavigationSplitView is correct pattern for sidebar + detail (iOS 17+ native)
- 13-01: @Observable preferred over ObservableObject for iOS 17+ cleaner code
- 13-01: Library/Types/Tags/Trash share libraryPath (same video collection, different filters)
- 13-01: Path dictionary pattern adopted for navigation state (prevents iPad rotation reset)
- 13-02: Settings as sheet, Capture as fullScreenCover from sidebar toolbar
- 13-02: preferredCompactColumn set to .detail so iPhone starts on Library view
- 13-02: PlaybookListContent helper extracts body to avoid nested NavigationStack
- 14-01: Thumbnail URLs derived from source_url (not stored in DB, no migration required)
- 14-01: YouTube maxresdefault.jpg resolution chosen for best quality
- 14-01: VideoResponse constructed explicitly to add derived thumbnail_url field

Full decision log in PROJECT.md Key Decisions table.

### Pending Todos

None yet.

### Blockers/Concerns

**Phase 13 (Navigation):**
- NavigationSplitView selection binding must be tested immediately (critical pitfall per research): RESOLVED - List(selection:) binding implemented in SidebarView
- Navigation state reset on iPad rotation: RESOLVED - path dictionary pattern adopted in NavigationModel
- PlaybookListView has internal NavigationStack that may need refactoring in Phase 15

**Phase 14 (Feed):**
- Image memory explosion risk requires thumbnail URLs + disk caching from day one: RESOLVED - Backend now provides thumbnail_url field
- Feed performance needs early profiling with 100+ videos on iPhone SE

**Phase 15 (Sidebar):**
- Button overlap fix needs SafeAreaInset testing with keyboard + toolbar visible simultaneously

**Phase 16 (Summary):**
- YouTube embed must respect TOS (official iframe only, no background audio)

## Session Continuity

Last session: 2026-01-31
Stopped at: Completed 14-01-PLAN.md (Backend Thumbnail URL Support)
Resume file: None
Next action: Continue Phase 14 (14-02 iOS Feed UI)

## Milestone History

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v1 MVP | 1-12 | 70 | ✅ Complete | 2026-01-28 |
| v1.1 UI Polish | 13-16 | 3 | 🚧 In progress | - |

See [MILESTONES.md](MILESTONES.md) for v1 details.

## Pre-Launch Tasks (v1)

Before App Store submission:
- [ ] Create 5 App Store screenshots (1260×2736)
- [ ] Record 15-30s app preview video
- [ ] Upload materials to App Store Connect
- [ ] Final TestFlight testing
- [ ] Submit for App Review

## Infrastructure

| Component | URL/Location | Status |
|-----------|--------------|--------|
| Backend API | https://backend-production-d73a.up.railway.app | ✓ Live |
| PostgreSQL | Railway managed | ✓ Connected |
| iOS App | ios/Scrollsmith.xcodeproj | ✓ Building |

## Environment Variables (Railway)

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes* | OpenAI API key for Whisper transcription |
| `ASSEMBLYAI_API_KEY` | No | AssemblyAI API key (fallback transcription) |
| `ANTHROPIC_API_KEY` | Yes | Anthropic Claude API key for AI summarization |
| `SENTRY_DSN` | No | Sentry DSN for error monitoring |

*At least one transcription API key is required for camera roll uploads to work.

## Notes

- Mode: YOLO (auto-approve)
- Depth: Comprehensive
- Parallelization: Enabled
- No blockers (v1.1 ready to plan)

## Archives

v1 milestone archived to:
- [milestones/v1-ROADMAP.md](milestones/v1-ROADMAP.md) — Full phase details (12 phases, 70 plans)
- [milestones/v1-REQUIREMENTS.md](milestones/v1-REQUIREMENTS.md) — All 85 requirements
- [milestones/v1-MILESTONE-AUDIT.md](milestones/v1-MILESTONE-AUDIT.md) — Integration verification
