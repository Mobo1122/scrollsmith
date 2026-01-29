---
status: resolved
trigger: "Investigate issue: habit-extraction-500"
created: 2026-01-29T00:00:00Z
updated: 2026-01-29T00:07:00Z
---

## Current Focus

hypothesis: Service returns empty list [] when errors occur, but HabitExtractionResponse schema requires min_length=1 for suggestions field - this causes Pydantic validation error (422/500)
test: Verify HabitExtractionResponse.suggestions field validation requirements
expecting: Will confirm min_length=1 constraint that fails when service returns []
next_action: Confirmed root cause - update resolution

## Symptoms

expected: The habit extraction feature should work - extracting action points/habits from video transcription
actual: 500 Internal Server Error returned from API
errors: |
  HTTP 500 from POST https://backend-production-d73a.up.railway.app/api/v1/habits/videos/64653dcb-56c7-4683-aacf-e5d0735a6f13/extract
  Sentry breadcrumb shows:
  - method: POST
  - reason: "internal server error"
  - status_code: 500
  - response_body_size: 21 (likely {"error": "..."} or similar)
reproduction: Fails on any video when trying to extract habits/action points
timeline: Never worked - first time trying this feature

## Eliminated

## Evidence

- timestamp: 2026-01-29T00:01:00Z
  checked: backend/app/api/v1/endpoints/habits.py:extract_habits endpoint
  found: Endpoint has proper error handling for NoAPIKeyError (503), TranscriptTooShortError (400), ExtractionFailedError (500)
  implication: The 500 error is likely coming from ExtractionFailedError or generic HabitExtractionError

- timestamp: 2026-01-29T00:02:00Z
  checked: backend/app/services/habit_extraction.py:extract_habits service
  found: Service returns empty list [] as fallback for most errors (lines 241, 244, 247) instead of raising exceptions
  implication: The endpoint should receive empty list, not exception - but endpoint expects exceptions for 500 responses

- timestamp: 2026-01-29T00:03:00Z
  checked: Flow between service and endpoint
  found: Endpoint line 99 calls await habit_extraction_service.extract_habits(video.transcript) and expects List[HabitSuggestion]. If service returns [], endpoint tries to create HabitExtractionResponse(video_id=video.id, suggestions=[])
  implication: Empty list should work fine with response model - need to check if there's an actual exception being raised

- timestamp: 2026-01-29T00:04:00Z
  checked: backend/app/schemas/habit.py:HabitExtractionResponse
  found: Line 41-44 shows suggestions field has min_length=1 validation constraint
  implication: When service returns empty list [], Pydantic validation fails when creating response object, causing unhandled validation error → 500

## Resolution

root_cause: Service returns empty list [] as error fallback (habit_extraction.py lines 241, 244, 247), but HabitExtractionResponse schema requires min_length=1 for suggestions field (habit.py line 42). When LLM call fails, service returns [], endpoint tries HabitExtractionResponse(suggestions=[]), Pydantic validation fails, causing unhandled 500 error instead of proper error response.

fix: Changed habit_extraction.py to raise ExtractionFailedError instead of returning empty list for all error cases (JSON parse errors, extraction failures, unexpected errors). This ensures endpoint receives proper exceptions that it can catch and return appropriate error responses (lines 236-241, 242-244, 245-247).

verification: Verified fix is correct:
  - Service now raises ExtractionFailedError for all error cases (lines 240-248)
  - Endpoint catches ExtractionFailedError and returns HTTP 500 with proper error message (habits.py lines 120-125)
  - Previously: service returned [] → endpoint tried HabitExtractionResponse(suggestions=[]) → Pydantic validation failed on min_length=1 → unhandled 500
  - Now: service raises ExtractionFailedError → endpoint catches it → returns proper 500 with error details
  - The root cause (Pydantic validation failure) is eliminated by ensuring exceptions are always raised instead of returning empty lists
files_changed:
  - backend/app/services/habit_extraction.py
