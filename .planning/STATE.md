# State: Scrollsmith

**Last Updated:** 2026-01-27

## Project Reference

See: [.planning/PROJECT.md](.planning/PROJECT.md) (updated 2026-01-23)

**Core value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits

**Current focus:** Phase 11 Infrastructure & Polish

## Architecture Note (2026-01-23)

**TikTok/Instagram URL support deferred to v2** due to macOS 13 dev environment (WhisperKit requires macOS 14+).

**v1 Transcription Strategy:**
- **Camera roll uploads:** iOS extracts audio → Backend transcribes via Whisper/AssemblyAI
- **YouTube URLs:** Fetch captions via youtube-transcript-api → Show "unavailable" if no captions
- **TikTok/IG URLs:** Not supported in v1 (users download to camera roll instead)

## Current Phase

**Phase:** 11 of 12 (Infrastructure & Polish)
**Goal:** Analytics, crash reporting, webhook retry, error handling
**Progress:** 0/6 plans
**Plans:** 0/6 complete

## Milestone Progress

**Milestone:** v1
**Total Phases:** 12
**Completed:** 10
**In Progress:** 0
**Pending:** 2

| Phase | Status | Progress |
|-------|--------|----------|
| 1 - Foundation | ✓ Complete | 4/4 plans |
| 2 - Authentication | ✓ Complete | 6/6 plans |
| 3 - Video Capture (iOS) | ✓ Complete | 6/6 plans (updated scope) |
| 4 - Transcription | ✓ Complete | 4/4 plans (server-side v1) |
| 5 - AI Summarization | ✓ Complete | 6/6 plans |
| 6 - Playbooks & Organization | ✓ Complete | 7/7 plans |
| 7 - Summary Display | ✓ Complete | 6/6 plans |
| 8 - Subscription System | ✓ Complete | 8/8 plans |
| 9 - Habit Extraction | ✓ Complete | 4/4 plans |
| 10 - Habit Tracking | ✓ Complete | 7/7 plans |
| 11 - Infrastructure & Polish | ○ Pending | 0/6 plans |
| 12 - Legal & Launch Prep | ○ Pending | 0/5 plans |

**Overall Progress:** █████████░ 87% (59/68 plans)

## Requirements Coverage

**Total v1 Requirements:** 85
**Mapped to Phases:** 85
**In Progress:** 0
**Completed:** 65 (INFR-01 through INFR-07, AUTH-01 through AUTH-12, CAPT-01 through CAPT-16, SUMM-01 through SUMM-11, SUBS-01 through SUBS-13, HABT-01 through HABT-17)
**Unmapped:** 0 ✓

## Recent Activity

- 2026-01-27: **Completed Phase 10 Habit Tracking** (7/7 plans, HABT-05 to HABT-17 verified)
- 2026-01-27: Completed Plan 10-07 Habit Detail UI (4 tasks, 15min)
- 2026-01-27: Completed Plan 10-06 Habit List UI (3 tasks, 21min)
- 2026-01-26: Completed Plan 10-04 Notification Scheduling (2 tasks, 15min)
- 2026-01-26: Completed Plan 10-05 iOS Habit Completion & Update APIs (3 tasks, 11min)
- 2026-01-26: Completed Plan 10-03 Habit Completion Endpoints (2 tasks, 2min)
- 2026-01-26: Completed Plan 10-02 Habit Reminder Fields (3 tasks, 2min)
- 2026-01-26: Completed Plan 10-01 HabitCompletion Model (2 tasks, 3min)
- 2026-01-26: **Completed Phase 9 Habit Extraction** (4/4 plans, HABT-01 to HABT-04 verified)
- 2026-01-26: Completed Plan 09-04 Habit Selection UI (4 tasks, 3min)
- 2026-01-26: Completed Plan 09-03 Habit iOS Models (3 tasks, 10min)
- 2026-01-26: Completed Plan 09-02 Habit API Endpoints (2 tasks, 2min)
- 2026-01-26: Completed Plan 09-01 Habit Extraction Service (2 tasks, 2min)
- 2026-01-24: **Completed Phase 7 Summary Display** (6/6 plans - gap closure complete)
- 2026-01-24: Completed Plan 07-06 Navigation Integration (2 tasks, 5min)
- 2026-01-24: Phase 7 Verification found navigation gap - Plan 07-06 created
- 2026-01-24: Completed Plan 07-05 Video Detail Integration (3 tasks, 5min)
- 2026-01-24: Completed Plan 07-04 Swipeable Card View (2 tasks, 4min)
- 2026-01-23: Completed Plan 07-03 Summary Display Views (2 tasks, 2min)
- 2026-01-23: Completed Plan 07-01 Summary Models & ViewModel (3 tasks, 9min)
- 2026-01-23: Completed Plan 07-02 Deep Links & Inline Player (2 tasks, 2min)
- 2026-01-23: **Completed Phase 6 Playbooks & Organization** (7/7 plans)
- 2026-01-23: Completed Plan 06-07 iOS Video UI (3 tasks, 6min)
- 2026-01-23: Completed Plan 06-06 iOS Playbook UI (3 tasks, 4min)
- 2026-01-23: Completed Plan 06-05 Bulk Operations API (3 tasks, 8min)
- 2026-01-23: Completed Plan 06-04 Video Search & Organization API (4 tasks)
- 2026-01-23: Completed Plan 06-03 Playbook CRUD API (3 tasks, 3min)
- 2026-01-23: Completed Plan 06-02 iOS SwiftData Models (work in 06-01)
- 2026-01-23: Completed Plan 06-01 Schema Migration (many-to-many + FTS)
- 2026-01-23: **Completed Phase 5 AI Summarization** (6/6 plans, all 8 requirements verified)
- 2026-01-23: **Completed Phase 4 Transcription** (server-side v1 architecture)
- 2026-01-23: Connected Railway to GitHub for auto-deploy
- 2026-01-23: Architecture change: Deferred TikTok/IG URL support to v2 (macOS 14+ required for WhisperKit)
- 2026-01-21: Completed Phase 3 Video Capture (all 6 plans)
- 2026-01-20: Completed Phase 2 Authentication (all 6 plans)
- 2026-01-20: Completed Phase 1 Foundation (all 4 plans)
- 2026-01-18: Project initialized

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

*At least one transcription API key is required for camera roll uploads to work.

## Decisions

| Decision | Phase | Rationale | Status |
|----------|-------|-----------|--------|
| UUID primary keys for all models | 01-01 | Better for distributed systems, prevents enumeration | ✓ Implemented |
| Async SQLAlchemy throughout | 01-01 | Better scalability for I/O-bound operations | ✓ Implemented |
| Track migration files in git | 01-01 | Essential for database version control in team environments | ✓ Implemented |
| Python 3.9 Optional[] syntax | 01-01 | Ensures compatibility with macOS default Python | ✓ Implemented |
| SwiftData unidirectional relationships | 01-02 | Avoids circular reference macro errors in SwiftData | ✓ Implemented |
| Actor-based API client | 01-02 | Thread-safety without manual locks | ✓ Implemented |
| Remove explicit foreign key UUIDs | 01-02 | SwiftData manages relationships automatically | ✓ Implemented |
| Railway variable references | 01-03 | Use ${{Service.VAR}} for cross-service config | ✓ Implemented |
| PhotosPicker for video selection | 03-01 | Native SwiftUI, no explicit permissions needed | ✓ Implemented |
| Regex-based URL validation | 03-03 | Simple, no dependencies, easy to maintain | ✓ Implemented |
| App Groups for Share Extension | 03-05 | Required for shared SwiftData container | ✓ Implemented |
| ~~On-device transcription for TikTok/IG~~ | 04-01 | **DEFERRED TO v2** - macOS 14+ required for WhisperKit toolchain | ✗ Removed |
| ~~WhisperKit for iOS 17+~~ | 04-03 | **DEFERRED TO v2** - macOS 14+ required for WhisperKit toolchain | ✗ Removed |
| Server-side Whisper/AssemblyAI | 04-01 | Backend transcribes camera roll uploads, simpler iOS code | ✓ Implemented |
| youtube-transcript-api | 04-05 | No API key required, no rate limits, instant captions | ✓ Implemented |
| Railway GitHub auto-deploy | 04-01 | Connected Railway to GitHub with root dir set to `backend` | ✓ Implemented |
| AsyncAnthropic for Claude API | 05-01 | Non-blocking async client for FastAPI compatibility | ✓ Implemented |
| tenacity for API retries | 05-01 | Exponential backoff with jitter for rate limit handling | ✓ Implemented |
| Claude Haiku 4.5 for free tier | 05-02 | Cost efficiency ($1/$5 per MTok) for bullet summaries | ✓ Implemented |
| Summary caching in Video model | 05-02 | Avoid redundant API calls, store in summary_bullets + tags | ✓ Implemented |
| Server-side tier gating | 05-03 | Security: subscription tier checked on backend, not client-side | ✓ Implemented |
| Structured 403 error response | 05-03 | UX: provides upgrade_url and format_requested for iOS upgrade prompt | ✓ Implemented |
| Claude Sonnet for Pro formats | 05-04 | Better reasoning for complex step extraction and categorization | ✓ Implemented |
| Auto-generate bullets for tags | 05-04 | Tags always from bullets - consistency across all formats | ✓ Implemented |
| Heuristic quality detection | 05-05 | Simple word count/punctuation/repetition checks - no ML overhead | ✓ Implemented |
| Quality warnings in response | 05-05 | iOS can show quality warning regardless of cache status | ✓ Implemented |
| user_edited_summary flag | 05-06 | Protects user edits from auto-regeneration unless regenerate=true | ✓ Implemented |
| Partial updates for summary editing | 05-06 | PATCH endpoint supports editing only specific fields | ✓ Implemented |
| video_playbooks association table | 06-01 | Many-to-many relationship with added_at for join date sorting | ✓ Implemented |
| is_system flag on Playbook | 06-01 | Protects Favorites playbook from deletion | ✓ Implemented |
| Weighted tsvector for search | 06-01 | tags=A, summary=B, transcript=C - prioritized full-text search | ✓ Implemented |
| GIN index on search_vector | 06-01 | Sub-millisecond full-text search performance | ✓ Implemented |
| ts_rank weighted search | 06-04 | Tags > Summary > Transcript priority for relevance | ✓ Implemented |
| HTML mark highlighting | 06-04 | Use <mark> tags for search highlights - standard HTML5 | ✓ Implemented |
| Tag normalization on update | 06-04 | Strip, dedupe, filter empty on PATCH /tags | ✓ Implemented |
| Bulk delete with RETURNING | 06-05 | Efficiently returns deleted IDs without separate query | ✓ Implemented |
| ON CONFLICT DO NOTHING for bulk move | 06-05 | Idempotent bulk operations handle duplicates | ✓ Implemented |
| Max 100 videos per bulk request | 06-05 | Prevents excessive load while allowing meaningful batches | ✓ Implemented |
| @Observable for PlaybookViewModel | 06-06 | iOS 17+ macro simpler than ObservableObject | ✓ Implemented |
| lastSelectedPlaybookId | 06-06 | 'Remember last selected' behavior for batch operations | ✓ Implemented |
| Horizontal chip picker | 06-06 | Quick Playbook selection without navigation | ✓ Implemented |
| Long-press for selection mode | 06-07 | Standard iOS pattern (Photos app) | ✓ Implemented |
| 250ms search debounce | 06-07 | Balance responsiveness vs API load | ✓ Implemented |
| FlowLayout for tag chips | 06-07 | Natural wrapping of tag chips | ✓ Implemented |
| 20 tag maximum | 06-07 | Prevent UI clutter, reasonable limit | ✓ Implemented |
| HTTPS-only deep links | 07-02 | URL schemes change frequently; HTTPS reliably triggers app interception | ✓ Implemented |
| Thumbnail-first video loading | 07-02 | Faster initial display, saves memory until playback requested | ✓ Implemented |
| @Observable for SummaryViewModel | 07-01 | iOS 17+ macro, matches PlaybookViewModel pattern | ✓ Implemented |
| UserDefaults for step completion | 07-01 | Simple per-video keying, no SwiftData overhead | ✓ Implemented |
| CodingKeys for snake_case mapping | 07-01 | Explicit mapping over keyDecodingStrategy for clarity | ✓ Implemented |
| parsedSteps/parsedCards computed | 07-01 | Lazy JSON parsing, nil-safe, no upfront decode | ✓ Implemented |
| Circle bullet indicators | 07-03 | Colored circles (accentColor) for visual hierarchy | ✓ Implemented |
| 4pt line spacing | 07-03 | ADHD-friendly readability per RESEARCH.md | ✓ Implemented |
| Timeline with step numbers | 07-03 | Shows number when incomplete, checkmark when done | ✓ Implemented |
| Color-coded connecting lines | 07-03 | Green for completed, gray for pending steps | ✓ Implemented |
| 120pt swipe threshold | 07-04 | Balance between intentional swipe and accidental trigger | ✓ Implemented |
| Rotation = offset/20 degrees | 07-04 | Subtle rotation effect follows drag direction | ✓ Implemented |
| 1.5s toast duration | 07-04 | Long enough to read, short enough not to block | ✓ Implemented |
| 2 background cards | 07-04 | Visual hint of remaining cards without clutter | ✓ Implemented |
| Segmented control with lock icons | 07-05 | Shows all formats, gates access on selection | ✓ Implemented |
| Blurred Pro teaser | 07-05 | "See more with Pro" for locked formats | ✓ Implemented |
| isPro placeholder | 07-05 | Always false until Phase 8 wires RevenueCat | ✓ Implemented |
| View Original FAB behavior split | 07-05 | YouTube/TikTok/IG deep link, camera roll inline player | ✓ Implemented |
| NavigationLink with disabled modifier | 07-06 | Disable navigation in selection mode, keeps pattern simple | ✓ Implemented |
| buttonStyle(.plain) for NavigationLink | 07-06 | Preserves grid item appearance without button styling | ✓ Implemented |
| Claude Sonnet for habit extraction | 09-01 | Better reasoning for extracting specific, actionable habits | ✓ Implemented |
| Structured outputs for habit extraction | 09-01 | Guarantees valid JSON response with correct schema | ✓ Implemented |
| System prompt constrains habits | 09-01 | Ensures habits are specific, recurring, derived, actionable | ✓ Implemented |
| Habits API under /habits prefix | 09-02 | Extraction at /habits/videos/{id}/extract keeps all habit endpoints together | ✓ Implemented |
| Pro tier gate on habit creation | 09-02 | Both extraction AND creation require Pro subscription | ✓ Implemented |
| HabitFrequency enum with rawValue | 09-03 | Matches backend enum values exactly (daily, 3x_weekly, weekly) | ✓ Implemented |
| HabitSelectionState struct | 09-03 | Tracks selection and frequency override for each suggestion in UI | ✓ Implemented |
| APIError.proRequired case | 09-03 | Specific error for 403 responses to trigger paywall display | ✓ Implemented |
| @Observable state machine in ViewModel | 09-03 | Using iOS 17+ macro, consistent with other ViewModels | ✓ Implemented |
| Sparkles icon for action points button | 09-04 | Conveys AI-powered feature | ✓ Implemented |
| Inline frequency picker on selection | 09-04 | Reveals segmented picker when checkbox selected | ✓ Implemented |
| Lock icon overlay for free users | 09-04 | Consistent with existing paywall pattern | ✓ Implemented |
| reminder_days null = daily | 10-02 | Null means "every day" for daily habits | ✓ Implemented |
| Weekday encoding 1-7 (Sun-Sat) | 10-02 | ISO weekday standard for reminder_days array | ✓ Implemented |
| is_active server_default='true' | 10-02 | Existing habits remain active after migration | ✓ Implemented |
| Gap <= 2 for streak forgiveness | 10-03 | gap=1 consecutive, gap=2 missed one day, gap>=3 breaks streak | ✓ Implemented |
| Flush before streak calculation | 10-03 | Ensures completion is in DB before PostgreSQL window function runs | ✓ Implemented |
| Cache streaks on Habit model | 10-03 | Avoid recalculating streaks on every habit list fetch | ✓ Implemented |
| HabitCompletion local-only model | 10-05 | Share Extension doesn't need completion tracking | ✓ Implemented |
| user_timezone for completion request | 10-05 | Backend expects snake_case user_timezone for streak calc | ✓ Implemented |
| Default timezone parameter | 10-05 | TimeZone.current.identifier reduces boilerplate | ✓ Implemented |
| UNCalendarNotificationTrigger for reminders | 10-04 | Handles DST, device restarts, low power mode correctly | ✓ Implemented |
| nonisolated delegate methods | 10-04 | UNUserNotificationCenterDelegate methods can't be @MainActor isolated | ✓ Implemented |
| Method-level @MainActor for ViewModels | 10-06 | SwiftUI @State + @Observable requires non-isolated class | ✓ Implemented |
| HabitDTO Hashable | 10-06 | Required for navigationDestination(item:destination:) | ✓ Implemented |

## Next Actions

**Primary:** Phase 11 Infrastructure & Polish (6 plans)
**Goal:** Analytics, crash reporting, webhook retry, error handling

## Manual Xcode Setup Required

### Phase 3 Setup (Share Extension)

1. **Add Share Extension target**
   - File → New → Target → Share Extension
   - Product Name: ScrollsmithShare
   - Add files from `ios/ScrollsmithShare/` to the target

2. **Configure App Groups**
   - Main app: Signing & Capabilities → + Capability → App Groups
   - Share Extension: Same process
   - App Group ID: `group.com.scrollsmith.shared`

3. **Share Extension activation rules** (in ScrollsmithShare/Info.plist):
   - NSExtensionActivationSupportsWebURLWithMaxCount: 1
   - NSExtensionActivationSupportsMovieWithMaxCount: 1

### ~~Phase 4 Setup (WhisperKit)~~ - DEFERRED TO v2

~~WhisperKit requires macOS 14+ for the toolchain. Dev machine is macOS 13.~~

**v2 TODO:** Add WhisperKit via SPM once dev environment is on macOS 14+:
- URL: `https://github.com/argmaxinc/WhisperKit`
- Add Speech permission to Info.plist

### Phase 4 Setup (v1 - Server-Side Transcription)

No special Xcode setup required. Video files are uploaded to backend for transcription.

## Notes

- Mode: YOLO (auto-approve)
- Depth: Comprehensive (8-12 phases, 5-10 plans each)
- Parallelization: Enabled
- No blockers
