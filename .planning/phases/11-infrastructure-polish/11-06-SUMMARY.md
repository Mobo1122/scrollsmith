---
phase: 11-infrastructure-polish
plan: 06
subsystem: backend-resilience
tags: [error-handling, timeout, logging, llm, fallback]
requires: [11-01]
provides:
  - LLM timeout handling (30 seconds)
  - Graceful fallback responses on LLM failures
  - Structured logging for all LLM operations
affects: [summary-endpoints, habit-endpoints]
tech-stack:
  added: []
  patterns: [timeout-handling, fallback-pattern, structured-logging]
key-files:
  created: []
  modified:
    - backend/app/services/summarization.py
    - backend/app/services/habit_extraction.py
decisions:
  - decision: 30-second timeout for all LLM API calls
    rationale: Prevents hanging requests and provides clear failure point
    date: 2026-01-27
  - decision: Return fallback responses instead of raising on LLM errors
    rationale: Better UX - users see error message instead of 500 error
    date: 2026-01-27
  - decision: Validation errors still raise exceptions
    rationale: Validation failures (too short, no API key) should fail fast
    date: 2026-01-27
metrics:
  duration: 3min
  completed: 2026-01-27
---

# Phase 11 Plan 06: LLM Error Handling Enhancement Summary

**One-liner:** Add 30-second timeouts, fallback responses, and structured logging to all LLM operations

## What Was Built

### Task 1: Enhanced Summarization Service
- Replaced standard logging with structlog `get_logger`
- Added `asyncio.timeout(30)` wrapper to `_call_claude` method
- Implemented structured logging with context:
  - `summarization_api_call_start` with model name
  - `summarization_api_call_success` on completion
  - `summarization_timeout` on timeout errors
  - `summarization_rate_limit` on 429 errors
  - `summarization_server_error` on 5xx errors
  - `summarization_client_error` on 4xx errors
- Added three fallback methods:
  - `_fallback_bullet_summary()`: Returns error bullets when LLM fails
  - `_fallback_step_checklist()`: Returns single-step error message
  - `_fallback_cards()`: Returns 3-card error explanation
- Updated all generate methods to return fallbacks on LLM failures
- Preserved validation error raising (TranscriptTooShortError, NoAPIKeyError)

### Task 2: Enhanced Habit Extraction Service
- Replaced standard logging with structlog `get_logger`
- Added `asyncio.timeout(30)` wrapper to `_call_claude` method
- Implemented structured logging with context:
  - `habit_extraction_start` with word count
  - `habit_extraction_api_call_start` with model name
  - `habit_extraction_api_call_success` on completion
  - `habit_extraction_success` with habit count
  - `habit_extraction_timeout` on timeout errors
  - `habit_extraction_rate_limit` on 429 errors
  - `habit_extraction_server_error` on 5xx errors
  - `habit_extraction_client_error` on 4xx errors
  - `habit_extraction_failed` on extraction errors
  - `habit_extraction_parse_error` on JSON parsing errors
  - `habit_extraction_unexpected_error` on unexpected failures
- Updated `extract_habits` to return empty list on LLM failures
- Preserved validation error raising (TranscriptTooShortError, NoAPIKeyError)

## Technical Implementation

### Timeout Pattern
```python
async with asyncio.timeout(30):
    response = await self.client.messages.create(**kwargs)
```

### Fallback Pattern
```python
except (NoAPIKeyError, TranscriptTooShortError):
    raise  # Validation errors still fail fast
except SummarizationFailedError as e:
    logger.error("summarization_bullets_failed", error=str(e))
    return self._fallback_bullet_summary(str(e))
```

### Structured Logging Pattern
```python
logger.info("summarization_api_call_start", model=model)
# ... API call ...
logger.info("summarization_api_call_success", model=model)
```

## Deviations from Plan

None - plan executed exactly as written.

## Testing Evidence

### Import Verification
```
✓ Both services import without errors
✓ Structured logging is used throughout
✓ Timeout handling is implemented (30 seconds)
✓ Fallback responses are available
```

## Requirements Coverage

**Enhanced:** INFR-06 (LLM Error Handling)
- ✓ 30-second timeouts on all LLM API calls
- ✓ Timeout errors logged with context
- ✓ Failed LLM calls return graceful fallback response
- ✓ All LLM errors captured in structured logs

## Integration Points

### Dependencies
- **Plan 11-01**: Uses `backend/app/core/logging.py` get_logger() function

### Affects
- **Summary endpoints**: `/api/summaries/*` now return fallback content on LLM failures
- **Habit endpoints**: `/api/habits/videos/{id}/extract` returns empty array on failures

### Production Impact
- **Better UX**: Users see error messages instead of 500 errors
- **Better monitoring**: Railway can aggregate structured JSON logs
- **Better debugging**: Correlation IDs track requests, structured context aids investigation
- **Timeout protection**: No more hanging requests waiting indefinitely on Claude API

## Decisions Made

| Decision | Options Considered | Choice & Rationale |
|----------|-------------------|-------------------|
| Timeout duration | 15s, 30s, 60s | **30s** - Balance between responsiveness and Claude API processing time |
| Fallback strategy | Raise exception vs return fallback | **Return fallback** - Better UX, user sees message vs generic 500 error |
| Validation error handling | Return fallback vs raise | **Raise** - Validation failures should fail fast, not mask configuration issues |
| Logging library | Standard logging vs structlog | **structlog** - Already integrated in 11-01, JSON output in production |

## Known Limitations

1. **Fallback content is generic** - Doesn't attempt partial recovery or retry logic
2. **Empty habit list may confuse users** - No UI indicator that extraction failed vs no habits found
3. **Timeout includes retry time** - 30s covers all 5 retry attempts, not per-attempt timeout

## Next Phase Readiness

### Enables
- **Phase 11 completion**: All infrastructure requirements met
- **Phase 12**: Reliable error handling foundation for production launch

### Blockers
None identified.

### Recommendations
1. Consider adding retry count to structured logs for debugging tenacity behavior
2. Add backend health check endpoint that validates LLM service connectivity
3. Monitor timeout frequency in production to tune 30s threshold

## Time Analysis

- **Started:** 2026-01-27 16:30:02 UTC
- **Completed:** 2026-01-27 16:32:59 UTC
- **Duration:** 3 minutes
- **Task breakdown:**
  - Task 1 (Summarization): 1.5min
  - Task 2 (Habit Extraction): 1.5min

**Performance notes:** Quick execution due to focused scope - only error handling additions, no refactoring needed.
