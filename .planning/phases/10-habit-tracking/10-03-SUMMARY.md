---
phase: 10-habit-tracking
plan: 03
subsystem: habit-tracking
tags: [api, endpoints, streaks, postgresql]

dependency-graph:
  requires:
    - 10-01  # Database schema with habit_completions table
    - 10-02  # Notification schema extensions
  provides:
    - POST /{habit_id}/complete endpoint
    - PATCH /{habit_id} endpoint
    - GET /{habit_id}/completions endpoint
    - Streak calculator service with 1-day forgiveness
  affects:
    - 10-04  # iOS habit UI will call these endpoints
    - 10-05  # Notifications will trigger completions

tech-stack:
  patterns:
    - PostgreSQL window functions for streak calculation
    - Timezone-aware date arithmetic (AT TIME ZONE)
    - Partial update pattern (model_dump exclude_unset)

key-files:
  created:
    - backend/app/services/streak_calculator.py
  modified:
    - backend/app/api/v1/endpoints/habits.py
    - backend/app/schemas/habit.py

decisions:
  - name: "Gap <= 2 for forgiveness"
    rationale: "gap=1 consecutive, gap=2 missed one day, gap>=3 breaks streak"
  - name: "Flush before streak calc"
    rationale: "Ensures completion is in DB before window function runs"
  - name: "Streak on habit model"
    rationale: "Cached values on Habit avoid recalculating on every list"

metrics:
  duration: 2min
  completed: 2026-01-26
---

# Phase 10 Plan 03: Habit Completion Endpoints Summary

**One-liner:** PATCH/complete/completions endpoints with PostgreSQL window function streak calculator using 1-day forgiveness

## What Was Built

### Task 1: Streak Calculator Service
Created `streak_calculator.py` service that calculates current and longest streaks using PostgreSQL window functions:

- **1-day forgiveness:** If user misses exactly 1 day, streak continues (gap <= 2)
- **Timezone-aware:** Uses `AT TIME ZONE` for accurate day boundary calculation
- **Efficient:** Single SQL query with CTEs, no N+1 queries
- **Returns:** Tuple of (current_streak, longest_streak)

### Task 2: Habit Endpoints
Added three endpoints to `habits.py`:

1. **PATCH /{habit_id}** - Partial updates for habit details
   - Uses `model_dump(exclude_unset=True)` for partial updates
   - Supports title, frequency, reminder_time, reminder_days, is_active

2. **POST /{habit_id}/complete** - Record habit completion
   - Stores user_timezone with each completion
   - Automatically recalculates streaks
   - Updates current_streak and longest_streak on habit

3. **GET /{habit_id}/completions** - Fetch completion history
   - Returns completions ordered by date descending
   - Includes current streak info for calendar display

### Schemas Added
- `HabitCompletionCreate` - Request with user_timezone
- `HabitCompletionResponse` - Response with streak info

## Technical Details

### Streak Algorithm
```sql
-- Gap calculation determines streak breaks:
-- gap=1: consecutive days (streak continues)
-- gap=2: missed 1 day (forgiveness, streak continues)
-- gap>=3: missed 2+ days (streak breaks)
SUM(CASE WHEN gap IS NULL OR gap <= 2 THEN 0 ELSE 1 END)
```

### Current Streak Detection
Current streak is the streak where `streak_end >= today - 1 day`, allowing for same-day or previous-day completions to count as current.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Gap <= 2 for forgiveness | Simple math: gap=1 consecutive, gap=2 skipped one |
| Flush before streak calc | Window function needs completion in DB first |
| Cache streaks on Habit | Avoid recalculating on every habit list fetch |
| User timezone in completion | Accurate day boundaries across time zones |

## Deviations from Plan

None - plan executed exactly as written. HabitCompletion model and Habit.completions relationship already existed from previous plans.

## Files Changed

| File | Change |
|------|--------|
| backend/app/services/streak_calculator.py | Created - streak calculation with forgiveness |
| backend/app/api/v1/endpoints/habits.py | Added PATCH, complete, completions endpoints |
| backend/app/schemas/habit.py | Added HabitCompletionCreate, HabitCompletionResponse |

## Commits

| Hash | Message |
|------|---------|
| 40cf610 | feat(10-03): add streak calculator service with 1-day forgiveness |
| 9097e4c | feat(10-03): add PATCH, completion, and completions endpoints |

## Success Criteria Verification

- [x] PATCH /habits/{id} updates habit fields partially
- [x] POST /habits/{id}/complete records completion with timezone
- [x] GET /habits/{id}/completions returns completion history
- [x] Streak calculation uses 1-day forgiveness algorithm
- [x] Completing habit updates current_streak and longest_streak

## Next Phase Readiness

**Ready for Plan 10-04:** iOS habit tracking UI can now:
- Update habit details via PATCH
- Record completions via POST complete
- Fetch completion history for calendar display
- Display accurate streaks with forgiveness
