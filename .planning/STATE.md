# State: Scrollsmith

**Last Updated:** 2026-01-23

## Project Reference

See: [.planning/PROJECT.md](.planning/PROJECT.md) (updated 2026-01-23)

**Core value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits

**Current focus:** Phase 5 AI Summarization

## Architecture Note (2026-01-23)

**TikTok/Instagram URL support deferred to v2** due to macOS 13 dev environment (WhisperKit requires macOS 14+).

**v1 Transcription Strategy:**
- **Camera roll uploads:** iOS extracts audio → Backend transcribes via Whisper/AssemblyAI
- **YouTube URLs:** Fetch captions via youtube-transcript-api → Show "unavailable" if no captions
- **TikTok/IG URLs:** Not supported in v1 (users download to camera roll instead)

## Current Phase

**Phase:** 5 of 12 (AI Summarization)
**Goal:** Generate bullet-point summaries from transcripts using Claude API
**Progress:** 57% (4/7 plans)
**Plans:** 4/7 complete

## Milestone Progress

**Milestone:** v1
**Total Phases:** 12
**Completed:** 4
**In Progress:** 1
**Pending:** 7

| Phase | Status | Progress |
|-------|--------|----------|
| 1 - Foundation | ✓ Complete | 4/4 plans |
| 2 - Authentication | ✓ Complete | 6/6 plans |
| 3 - Video Capture (iOS) | ✓ Complete | 6/6 plans (updated scope) |
| 4 - Transcription | ✓ Complete | 4/4 plans (server-side v1) |
| 5 - AI Summarization | ◐ In Progress | 4/7 plans |
| 6 - Playbooks & Organization | ○ Pending | 0/6 plans |
| 7 - Summary Display | ○ Pending | 0/5 plans |
| 8 - Subscription System | ○ Pending | 0/8 plans |
| 9 - Habit Extraction | ○ Pending | 0/5 plans |
| 10 - Habit Tracking | ○ Pending | 0/7 plans |
| 11 - Infrastructure & Polish | ○ Pending | 0/6 plans |
| 12 - Legal & Launch Prep | ○ Pending | 0/5 plans |

**Overall Progress:** ████░░░░░░ 41% (24/59 plans)

## Requirements Coverage

**Total v1 Requirements:** 85
**Mapped to Phases:** 85
**In Progress:** 0
**Completed:** 36 (INFR-01 through INFR-05, AUTH-01 through AUTH-12, CAPT-01 through CAPT-16, TRANS-01 through TRANS-04)
**Unmapped:** 0 ✓

## Recent Activity

- 2026-01-23: **Completed Plan 05-04** Pro Format Generation Methods (Sonnet for steps/cards, auto-tag generation)
- 2026-01-23: **Completed Plan 05-03** Pro Summary Fields & Tier Gating (Video model + 403 for free users)
- 2026-01-23: **Completed Plan 05-02** Bullet Summary Generation (POST /videos/{id}/summarize endpoint)
- 2026-01-23: **Completed Plan 05-01** Claude API Foundation (AsyncAnthropic + Pydantic schemas)
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

## Next Actions

**Primary:** Phase 5 AI Summarization
**Goal:** Generate bullet-point summaries from transcripts
**Tasks:**
1. Add GPT-4 summarization endpoint to backend
2. Create summary generation service
3. Update Video model with summary fields
4. Add iOS summary display UI
5. Integrate summarization into transcription flow

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
