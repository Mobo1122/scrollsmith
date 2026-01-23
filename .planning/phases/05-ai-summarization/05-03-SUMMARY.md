---
phase: 05-ai-summarization
plan: 03
subsystem: backend-api
tags: [tier-gating, subscription, pro-features, database-migration]

dependency-graph:
  requires:
    - 05-02 (bullet summary generation endpoint)
    - 02-* (user authentication with subscription_tier field)
  provides:
    - Video model with Pro summary fields (summary_steps, summary_cards)
    - Tier-based access control for Pro formats
    - Cache checking for all summary formats
  affects:
    - 05-04 (Pro format generation will replace 501 stub)
    - 08-* (subscription system will manage tier upgrades)

tech-stack:
  added: []
  patterns:
    - Server-side subscription tier gating
    - Format-specific caching with JSON storage
    - Structured 403 error responses with upgrade prompts

files:
  created:
    - backend/alembic/versions/fb9ffa569e14_add_pro_summary_fields_to_video_model.py
  modified:
    - backend/app/models/video.py
    - backend/app/schemas/video.py
    - backend/app/api/v1/endpoints/videos.py

decisions:
  - name: "Server-side tier gating"
    rationale: "Security: client-side checks can be bypassed, server enforces access control"
  - name: "Structured 403 error response"
    rationale: "UX: provides upgrade_url and format_requested for iOS to show upgrade prompt"
  - name: "501 stub for Pro formats"
    rationale: "Separation of concerns: Plan 03 handles access control, Plan 04 handles generation"

metrics:
  duration: "2 minutes"
  completed: "2026-01-23"
---

# Phase 5 Plan 3: Pro Summary Fields & Tier Gating Summary

**One-liner:** Video model extended with summary_steps/cards fields, tier gating returns 403 for free users requesting Pro formats

## What Was Built

### Database Schema Update
Added two new Text columns to the `videos` table for Pro summary formats:
- `summary_steps` - Stores step-by-step summary JSON (nullable)
- `summary_cards` - Stores flashcard summary JSON (nullable)

Migration `fb9ffa569e14` adds these columns with proper upgrade/downgrade support.

### Pydantic Schema Update
Extended `VideoResponse` schema to include the new fields, ensuring API responses include Pro summary data when available.

### Tier Gating Logic
The summarize endpoint now enforces subscription-based access control:

1. **Free users requesting Pro formats (steps, cards):**
   - Returns 403 Forbidden
   - Response includes structured error with upgrade prompt:
     ```json
     {
       "detail": {
         "error": "pro_required",
         "message": "Steps format requires Pro subscription",
         "upgrade_url": "/subscribe/pro",
         "format_requested": "steps"
       }
     }
     ```

2. **Pro users requesting Pro formats:**
   - Pass tier gate
   - Currently get 501 Not Implemented (Plan 04 adds generation)

3. **All users requesting bullets:**
   - No tier restriction
   - Works as before

### Updated Cache Logic
Cache checking now handles all three formats:
- `bullets` - checks `video.summary_bullets`
- `steps` - checks `video.summary_steps`
- `cards` - checks `video.summary_cards`

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 4b5ac24 | feat | Add Pro summary fields to Video model and schemas |
| cc28ab4 | feat | Add tier gating to summarize endpoint |

## Decisions Made

1. **Server-side tier gating** - Subscription tier is checked on the backend, not client-side. This ensures security since client-side checks can be bypassed.

2. **Structured 403 error response** - The 403 response includes `error`, `message`, `upgrade_url`, and `format_requested` fields. This enables iOS to show a contextual upgrade prompt.

3. **501 stub for Pro format generation** - Plan 03 establishes access control, Plan 04 implements the actual generation methods. This separation keeps plans atomic.

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

Plan 05-04 can now:
- Implement `generate_step_summary()` and `generate_card_summary()` methods
- Replace the 501 stub with actual generation calls
- Save generated summaries to the new Video model fields

**No blockers for Plan 04.**
