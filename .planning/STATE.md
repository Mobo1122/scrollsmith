# State: Scrollsmith

**Last Updated:** 2026-01-23

## Project Reference

See: [.planning/PROJECT.md](.planning/PROJECT.md) (updated 2026-01-23)

**Core value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits

**Current focus:** Phase 4 Transcription - server-side transcription (simplified for macOS 13 dev environment)

## Architecture Change (2026-01-23)

**TikTok/Instagram URL support deferred to v2** due to macOS 13 dev environment (WhisperKit requires macOS 14+).

**v1 Transcription Strategy:**
- **Camera roll uploads:** iOS uploads video → Backend transcribes via Whisper/AssemblyAI → Delete file
- **YouTube URLs:** Fetch captions via youtube-transcript-api → Show "unavailable" if no captions
- **TikTok/IG URLs:** Not supported in v1 (users download to camera roll instead)

## Current Phase

**Phase:** 4 of 12 (Transcription) - **NEEDS RE-IMPLEMENTATION**
**Goal:** Server-side transcription for camera roll uploads, YouTube caption fetching
**Progress:** 0% (0/4 plans) - previous Phase 4 code needs removal/replacement
**Plans:** 0/4 complete

## Milestone Progress

**Milestone:** v1
**Total Phases:** 12
**Completed:** 4
**In Progress:** 0
**Pending:** 8

| Phase | Status | Progress |
|-------|--------|----------|
| 1 - Foundation | ✓ Complete | 4/4 plans |
| 2 - Authentication | ✓ Complete | 6/6 plans |
| 3 - Video Capture (iOS) | ✓ Complete | 6/6 plans (updated scope) |
| 4 - Transcription | ⟳ Rework | 0/4 plans (simplified for v1) |
| 5 - AI Summarization | ○ Pending | 0/7 plans |
| 6 - Playbooks & Organization | ○ Pending | 0/6 plans |
| 7 - Summary Display | ○ Pending | 0/5 plans |
| 8 - Subscription System | ○ Pending | 0/8 plans |
| 9 - Habit Extraction | ○ Pending | 0/5 plans |
| 10 - Habit Tracking | ○ Pending | 0/7 plans |
| 11 - Infrastructure & Polish | ○ Pending | 0/6 plans |
| 12 - Legal & Launch Prep | ○ Pending | 0/5 plans |

**Overall Progress:** ██░░░░░░░░ 25% (16/63 plans) - adjusted for simplified Phase 3-4

## Requirements Coverage

**Total v1 Requirements:** 85
**Mapped to Phases:** 85
**In Progress:** 0
**Completed:** 32 (INFR-01, INFR-02, INFR-03, INFR-05, AUTH-01 through AUTH-12, CAPT-01 through CAPT-16)
**Unmapped:** 0 ✓

## Recent Activity

- 2026-01-23: **Architecture change:** Deferred TikTok/IG URL support to v2 (macOS 14+ required for WhisperKit)
- 2026-01-23: Phase 4 rework started - removing on-device transcription, adding server-side
- 2026-01-21: Completed Phase 4 Transcription (original implementation - now being reworked)
- 2026-01-21: Completed Phase 3 Video Capture (all 7 plans)
- 2026-01-20: Started Phase 3 Video Capture
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

Add these to Railway for Phase 4 transcription:

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes* | OpenAI API key for Whisper transcription |
| `ASSEMBLYAI_API_KEY` | No | AssemblyAI API key (fallback transcription) |

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
| Server-side Whisper/AssemblyAI | 04-01 | Backend transcribes camera roll uploads, simpler iOS code | ○ Pending |
| youtube-transcript-api | 04-05 | No API key required, no rate limits, instant captions | ✓ Implemented |

## Next Actions

**Primary:** Rework Phase 4 Transcription for server-side approach
**Tasks:**
1. Remove iOS WhisperKit/Speech services (defer to v2)
2. Remove iOS MediaDownloadService (defer to v2)
3. Update TranscriptionOrchestrator for server-side only
4. Hide TikTok/IG URL paste UI in CaptureView (YouTube only for v1)
5. Add backend video file upload endpoint with Whisper/AssemblyAI
6. Update iOS APIClient for file upload with progress
**Next:** After Phase 4 rework, continue to Phase 5 AI Summarization

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
