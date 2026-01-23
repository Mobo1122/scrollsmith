---
phase: 06-playbooks-organization
plan: 04
completed: 2026-01-23
duration: ~10 min

subsystem: api
tags: [videos, search, playbooks, postgresql, full-text-search]

dependency-graph:
  requires: ["06-01"]
  provides: ["video-search", "playbook-assignment", "tag-editing", "uncategorized-filter"]
  affects: ["06-05", "06-06"]

tech-stack:
  added: []
  patterns:
    - "PostgreSQL full-text search with ts_rank and ts_headline"
    - "Raw SQL queries via SQLAlchemy text() for complex operations"
    - "ON CONFLICT DO NOTHING for idempotent assignment"

key-files:
  created: []
  modified:
    - backend/app/schemas/video.py
    - backend/app/api/v1/endpoints/videos.py

decisions:
  - id: "weighted-search-ranking"
    choice: "Tags > Summary > Transcript priority"
    rationale: "Tags are user-curated, most intentional; transcript is raw content"
  - id: "html-mark-highlighting"
    choice: "Use <mark> tags for search highlights"
    rationale: "Standard HTML5 element for highlighting text, easy to style in iOS"
  - id: "tag-normalization"
    choice: "Strip, dedupe, filter empty on update"
    rationale: "Prevents duplicate tags and trailing spaces from user input"

metrics:
  tasks-completed: 4
  tasks-total: 4
  commits: 4
---

# Phase 6 Plan 04: Video Search & Organization API Summary

Full-text search with weighted ranking, video-Playbook assignment, and tag editing endpoints.

## One-Liner

PostgreSQL full-text search with ts_rank/ts_headline, video-Playbook many-to-many operations, and tag editing API.

## What Was Built

### Task 1: Search and Assignment Schemas
- `VideoSearchResult`: Single result with rank and highlight
- `VideoSearchResponse`: Paginated search results with query
- `VideoAssignPlaybookRequest`: Assign video to Playbook
- `VideoPlaybooksResponse`: List Playbook IDs for a video
- `VideoUpdateTagsRequest`: Update tags (max 20)
- `VideoUpdateTagsResponse`: Updated tags response

### Task 2: Full-Text Search Endpoint
- `GET /videos/search?q=term` with weighted ranking
- Tags weight A (highest), summary weight B, transcript weight C
- `ts_headline` for highlighted matching text with `<mark>` tags
- Optional `playbook_id` parameter to scope search
- Pagination with `skip`/`limit`

### Task 3: Playbook Assignment Endpoints
- `POST /videos/{id}/playbooks` - Assign video to Playbook
- `DELETE /videos/{id}/playbooks/{pb_id}` - Remove assignment
- `GET /videos/{id}/playbooks` - List Playbook IDs for video
- Updated `GET /videos` to support:
  - `?playbook_id=xxx` - Filter by Playbook
  - `?uncategorized=true` - Videos not in any Playbook
- Playbook's `updated_at` refreshed on assignment for sorting

### Task 4: Tag Editing Endpoint
- `PATCH /videos/{id}/tags` replaces all tags
- Normalizes tags: trim whitespace, dedupe, filter empty
- Maximum 20 tags per video (schema validation)
- search_vector updates automatically via PostgreSQL trigger

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Search ranking weights | tags=A, summary=B, transcript=C | User-curated tags most intentional |
| Highlight format | HTML `<mark>` tags | Standard HTML5, easy iOS styling |
| Tag normalization | Strip, dedupe, filter | Prevent duplicate/whitespace issues |
| Assignment idempotency | ON CONFLICT DO NOTHING | Safe for repeated calls |

## Key Commits

| Hash | Description |
|------|-------------|
| 73f3a18 | Add search, assignment, and tag update schemas |
| f1b17d2 | Add full-text search endpoint for videos |
| 978b52c | Add Playbook assignment endpoints and filtering |
| ad0097a | Add tag editing endpoint for videos |

## Requirements Fulfilled

| ID | Requirement | Status |
|----|-------------|--------|
| PLAY-04 | Assign video to Playbook | Done |
| PLAY-06 | View uncategorized videos | Done |
| PLAY-07 | Edit video tags | Done |
| PLAY-08 | Search videos | Done |

## API Endpoints Added

```
POST   /api/v1/videos/{id}/playbooks        - Assign to Playbook
DELETE /api/v1/videos/{id}/playbooks/{pb}   - Remove from Playbook
GET    /api/v1/videos/{id}/playbooks        - List video's Playbooks
PATCH  /api/v1/videos/{id}/tags             - Update tags
GET    /api/v1/videos/search?q=term         - Full-text search
GET    /api/v1/videos?playbook_id=xxx       - Filter by Playbook
GET    /api/v1/videos?uncategorized=true    - Uncategorized videos
```

## Verification

- [x] Search returns ranked results with highlights
- [x] Search can be scoped to a Playbook
- [x] POST assigns video to Playbook
- [x] DELETE removes video from Playbook
- [x] GET /videos?uncategorized=true works
- [x] GET /videos?playbook_id=xxx filters correctly
- [x] PATCH /videos/{id}/tags updates tags

## Deviations from Plan

None - plan executed exactly as written. Bulk operation schemas were added by linter/parallel process but don't affect this plan's scope.

## Next Phase Readiness

Phase 6 Plan 05 (Bulk Operations API) can proceed:
- Many-to-many video_playbooks relationship verified working
- Video filtering by Playbook working
- Tag editing infrastructure in place
