---
phase: 09-habit-extraction
plan: 01
subsystem: api
tags: [claude, anthropic, structured-outputs, pydantic, habit-extraction]

# Dependency graph
requires:
  - phase: 05-ai-summarization
    provides: Claude API integration patterns, retry logic with tenacity
provides:
  - HabitExtractionService with Claude structured outputs
  - Pydantic schemas for habit API contracts
affects: [09-02 (habit API endpoints), 09-03 (iOS extraction UI)]

# Tech tracking
tech-stack:
  added: []
  patterns: [Claude structured outputs beta for guaranteed valid JSON]

key-files:
  created:
    - backend/app/services/habit_extraction.py
    - backend/app/schemas/habit.py
  modified: []

key-decisions:
  - "Claude Sonnet 4.5 for habit extraction (better reasoning than Haiku)"
  - "Structured outputs beta for guaranteed valid JSON response"
  - "System prompt constrains habits to specific, actionable, video-derived suggestions"
  - "Same 50-word minimum transcript length as summarization"

patterns-established:
  - "Structured outputs pattern: output_format with json_schema for guaranteed schema compliance"
  - "Habit suggestion structure: title, description, suggested_frequency (daily/3x_weekly/weekly)"

# Metrics
duration: 2min
completed: 2026-01-26
---

# Phase 9 Plan 01: Habit Extraction Service Summary

**Claude habit extraction service with structured outputs extracting 1-3 specific, actionable habits from video transcripts**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-26T20:23:02Z
- **Completed:** 2026-01-26T20:25:11Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- Created Pydantic v2 schemas for habit extraction API contracts (HabitSuggestion, HabitExtractionResponse, HabitCreateRequest, HabitResponse)
- Implemented HabitExtractionService using Claude Sonnet 4.5 with structured outputs beta
- System prompt constrains output to specific, actionable, video-derived habits (not generic self-help)
- Retry logic with tenacity matches existing summarization service pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Pydantic schemas for habit extraction** - `e4bfe65` (feat)
2. **Task 2: Create habit extraction service with Claude structured outputs** - `a4e21f8` (feat)

## Files Created

- `backend/app/schemas/habit.py` - Pydantic schemas: HabitSuggestion, HabitExtractionResponse, HabitCreateRequest, HabitResponse
- `backend/app/services/habit_extraction.py` - HabitExtractionService with Claude structured outputs, retry logic, singleton instance

## Decisions Made

1. **Claude Sonnet 4.5 (not Haiku)** - Better reasoning needed for extracting actionable habits from transcripts
2. **Structured outputs beta** - Guarantees valid JSON response with correct schema, eliminates parsing errors
3. **System prompt design** - Explicitly constrains habits to be SPECIFIC, RECURRING, DERIVED from video, and ACTIONABLE (phrased as verbs)
4. **Same 50-word minimum** - Consistent with summarization service transcript validation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Service uses existing ANTHROPIC_API_KEY environment variable already configured for summarization.

## Next Phase Readiness

- Habit extraction service ready for API endpoint integration (Plan 09-02)
- Schemas ready for iOS client model generation
- No blockers

---
*Phase: 09-habit-extraction*
*Completed: 2026-01-26*
