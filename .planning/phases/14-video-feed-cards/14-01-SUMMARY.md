---
phase: 14-video-feed-cards
plan: 01
subsystem: api
tags: [youtube, thumbnails, fastapi, pydantic]

# Dependency graph
requires:
  - phase: 01-backend-setup
    provides: FastAPI backend with video endpoints
  - phase: 02-video-models
    provides: Video model with source_url field
provides:
  - Backend API returns thumbnail_url field for all video responses
  - YouTube thumbnail URL extraction from source_url pattern
  - Backward compatible null thumbnail_url for non-YouTube sources
affects: [14-02-ios-feed-ui, 14-03-card-design]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "View-level transformation (thumbnail_url derived from source_url, not stored in DB)"
    - "YouTube thumbnail URL pattern: img.youtube.com/vi/{video_id}/maxresdefault.jpg"

key-files:
  created: []
  modified:
    - backend/app/schemas/video.py
    - backend/app/api/v1/endpoints/videos.py

key-decisions:
  - "Thumbnail URLs derived from source_url, not stored in database (no migration required)"
  - "YouTube maxresdefault.jpg resolution chosen for best quality"
  - "All VideoResponse construction points updated to populate thumbnail_url"

patterns-established:
  - "Helper function _extract_thumbnail_url() centralizes thumbnail URL logic"
  - "VideoResponse constructed explicitly (not model_validate) to add derived fields"

# Metrics
duration: 4min
completed: 2026-01-31
---

# Phase 14 Plan 01: Backend Thumbnail URL Support Summary

**API now returns thumbnail_url for YouTube videos using img.youtube.com/vi/{id}/maxresdefault.jpg pattern, null for camera roll**

## Performance

- **Duration:** 4 minutes
- **Started:** 2026-01-31T15:37:05Z
- **Completed:** 2026-01-31T15:41:09Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- VideoResponse and VideoSearchResult schemas include thumbnail_url field
- YouTube thumbnail URLs extracted from source_url via regex patterns
- All video endpoints (GET /videos, GET /videos/{id}, POST /transcribe, etc.) return thumbnail_url
- Backward compatible - null for camera roll and other non-YouTube sources
- No database migration required (field is derived, not stored)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add thumbnail_url to VideoResponse schema** - `323308e` (feat)
2. **Task 2: Extract YouTube thumbnail URL in video endpoints** - `135cf77` (feat)

## Files Created/Modified
- `backend/app/schemas/video.py` - Added thumbnail_url field to VideoResponse and VideoSearchResult
- `backend/app/api/v1/endpoints/videos.py` - Added _extract_thumbnail_url() helper, updated all endpoints to populate thumbnail_url

## Decisions Made

**1. Thumbnail URLs derived from source_url, not stored in database**
- Rationale: YouTube thumbnail URLs follow predictable pattern, no need to store
- Benefit: No database migration, no storage overhead
- Pattern: Extract video ID via regex, construct img.youtube.com URL

**2. Use maxresdefault.jpg for best quality**
- Rationale: Highest quality thumbnail available from YouTube (1920x1080)
- Fallback: YouTube serves lower resolution if maxresdefault unavailable

**3. Update all VideoResponse construction points**
- Rationale: Consistent API contract across all endpoints
- Changed: GET /videos, GET /videos/{id}, POST /transcribe, POST /videos, PATCH /videos/{id}/summary, GET /videos/search
- Pattern: Explicit VideoResponse construction with thumbnail_url=_extract_thumbnail_url(source_url)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - straightforward implementation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Backend ready for iOS feed implementation:
- thumbnail_url field available in all video responses
- YouTube videos return valid thumbnail URLs
- Camera roll videos return null (iOS can use local thumbnail)
- API contract backward compatible with existing iOS app

Next: Phase 14 Plan 02 will implement iOS feed UI consuming these thumbnail URLs.

---
*Phase: 14-video-feed-cards*
*Completed: 2026-01-31*
