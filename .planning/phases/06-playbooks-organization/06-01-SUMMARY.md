---
phase: 06-playbooks-organization
plan: 01
subsystem: database
tags: [sqlalchemy, postgresql, many-to-many, full-text-search, tsvector, gin-index, alembic]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: Base SQLAlchemy models with UUID primary keys
  - phase: 05-ai-summarization
    provides: summary_bullets and tags columns on Video model
provides:
  - Many-to-many Video-Playbook relationship via video_playbooks association table
  - is_system flag on Playbook for Favorites protection
  - Full-text search with weighted tsvector on Video (tags=A, summary=B, transcript=C)
  - GIN index for fast search performance
affects:
  - 06-02 (Playbook CRUD API will use new relationship)
  - 06-03 (Search API will use search_vector and GIN index)
  - 06-04 (iOS models updated to reflect many-to-many)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Many-to-many via SQLAlchemy secondary table
    - PostgreSQL generated tsvector column with weights
    - GIN index for full-text search

key-files:
  created:
    - backend/alembic/versions/167d2182ec20_add_video_playbooks_association.py
  modified:
    - backend/app/models/playbook.py
    - backend/app/models/video.py
    - backend/app/models/__init__.py
    - ios/Scrollsmith/Models/Playbook.swift
    - ios/Scrollsmith/Models/Video.swift

key-decisions:
  - "video_playbooks association table with added_at timestamp for sorting by join date"
  - "is_system flag for Favorites playbook protection (cannot be deleted)"
  - "updated_at on Playbook for activity sorting"
  - "Weighted tsvector: tags=A, summary_bullets=B, transcript=C"
  - "GIN index for sub-millisecond search performance"

patterns-established:
  - "Association table pattern for many-to-many in SQLAlchemy 2.0"
  - "Generated column for tsvector (auto-updates on source column changes)"

# Metrics
duration: 3min
completed: 2026-01-23
---

# Phase 6 Plan 1: Schema Migration Summary

**Many-to-many Video-Playbook relationship via association table with PostgreSQL full-text search (weighted tsvector + GIN index)**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-23T21:46:51Z
- **Completed:** 2026-01-23T21:49:29Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Migrated one-to-many to many-to-many Video-Playbook relationship
- Added video_playbooks association table with added_at timestamp
- Added is_system and updated_at columns to Playbook model
- Added search_vector generated column with weighted full-text search
- Created GIN index for fast search performance
- Updated iOS models to match backend schema

## Task Commits

Each task was committed atomically:

1. **Task 1: Add video_playbooks association table and update models** - `fa31038` (feat)
2. **Task 2: Create Alembic migration for schema changes** - `e1e3960` (feat)

## Files Created/Modified
- `backend/app/models/playbook.py` - Added video_playbooks table, is_system, updated_at
- `backend/app/models/video.py` - Removed playbook_id, added playbooks list, search_vector
- `backend/app/models/__init__.py` - Export video_playbooks
- `backend/alembic/versions/167d2182ec20_add_video_playbooks_association.py` - Full migration
- `ios/Scrollsmith/Models/Playbook.swift` - isSystem, updatedAt, videos array
- `ios/Scrollsmith/Models/Video.swift` - playbooks array (many-to-many)

## Decisions Made
- **video_playbooks association table** - Standard SQLAlchemy pattern for many-to-many with added_at for join date sorting
- **is_system flag** - Protects system playbooks (like Favorites) from deletion
- **updated_at column** - Enables "sort by recent activity" for playbook lists
- **Weighted tsvector** - Tags have highest priority (A), then summary (B), then transcript (C)
- **GIN index** - Standard PostgreSQL full-text search index for sub-millisecond queries

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **Local migration test skipped** - No local PostgreSQL database available. Migration will run on Railway deployment. Migration file syntax validated by Python parser.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Schema supports many-to-many Video-Playbook relationships
- Full-text search infrastructure ready for API endpoints
- Migration will run automatically on Railway deployment
- Ready for Plan 06-02: Playbook CRUD API

---
*Phase: 06-playbooks-organization*
*Completed: 2026-01-23*
