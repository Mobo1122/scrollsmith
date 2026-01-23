---
phase: 05-ai-summarization
plan: 05
subsystem: backend-api
tags: [claude-api, quality-detection, regeneration, prompt-caching, error-handling]

dependency-graph:
  requires:
    - 05-04 (Pro format generation methods)
    - 05-02 (bullet summary generation with caching support)
  provides:
    - Transcript quality detection (good/marginal/poor scoring)
    - Quality warnings in summarize response
    - Regeneration with prompt caching (90% cost reduction)
  affects:
    - 07-* (iOS summary display can show quality warnings)
    - Future error recovery and retry logic

tech-stack:
  added: []
  patterns:
    - Heuristic-based quality detection (word count, punctuation, repetition)
    - Quality warnings in API response for marginal/poor transcripts
    - Prompt caching via cache_control ephemeral for regeneration

files:
  created: []
  modified:
    - backend/app/services/summarization.py
    - backend/app/schemas/video.py
    - backend/app/api/v1/endpoints/videos.py

decisions:
  - name: "Heuristic quality detection (not ML-based)"
    rationale: "Simple, fast, no model overhead - catches common issues like short transcripts and repetition"
  - name: "Quality warnings included in response (not blocking)"
    rationale: "Marginal transcripts proceed with warning; poor transcripts blocked by _validate_transcript"
  - name: "Quality check on every request (cached and generated)"
    rationale: "iOS can always display quality warning regardless of cache status"

metrics:
  duration: "3 minutes"
  completed: "2026-01-23"
---

# Phase 5 Plan 5: Regeneration and Quality Detection Summary

**One-liner:** Heuristic transcript quality detection returns warnings for marginal/poor transcripts; regeneration uses prompt caching for 90% cost reduction

## What Was Built

### Quality Detection Method (summarization.py)

Added `check_transcript_quality(transcript)` to `SummarizationService`:

```python
def check_transcript_quality(self, transcript: str) -> dict:
    """Check transcript quality and return warnings if needed.

    Returns:
        {
            "quality": "good" | "marginal" | "poor",
            "word_count": int,
            "warnings": list[str],
            "recommendation": str | None
        }
    """
```

**Quality indicators checked:**
- **Word count:** < 100 = poor, 100-200 = marginal, 200+ = good
- **Average word length:** < 3 chars suggests transcription errors
- **Punctuation ratio:** < 1% suggests incoherent text
- **Repetition detection:** 5-word phrase repeating 3+ times suggests audio loop

### Response Schema (video.py)

Added `TranscriptQuality` Pydantic model:

```python
class TranscriptQuality(BaseModel):
    quality: Literal["good", "marginal", "poor"]
    word_count: int
    warnings: List[str] = Field(default_factory=list)
    recommendation: Optional[str] = None
```

Updated `SummarizeResponse` with optional `transcript_quality` field.

### Endpoint Integration (videos.py)

Quality check runs on every summarize request:

```python
# Check transcript quality and warn if marginal
quality_info = summarization_service.check_transcript_quality(video.transcript)
quality_warning = None

if quality_info["quality"] in ["marginal", "poor"]:
    quality_warning = TranscriptQuality(**quality_info)
    logger.warning(f"Video {video_id} has {quality_info['quality']} transcript quality")
```

Quality warning included in all response paths (cached and generated).

### Regeneration with Prompt Caching

Already implemented in Plans 02-04:
- `use_caching=True` passed when `regenerate=True`
- Methods add `cache_control: {"type": "ephemeral"}` for transcripts > 500 words
- 90% cost reduction on regeneration API calls

## Commits

| Hash | Type | Description |
|------|------|-------------|
| d11624a | feat | Add transcript quality detection method |
| 4b66e3c | feat | Add quality warnings to summarize response |

## Verification

All success criteria verified:

- [x] `check_transcript_quality` method exists in SummarizationService
- [x] Quality checks word count, avg word length, punctuation, repetition
- [x] Returns quality score (good/marginal/poor), warnings array, recommendation
- [x] `TranscriptQuality` Pydantic schema added to video.py
- [x] `SummarizeResponse` includes optional `transcript_quality` field
- [x] Summarize endpoint calls `check_transcript_quality` before generation
- [x] Quality warnings included in response for marginal/poor transcripts
- [x] Regeneration flag passes `use_caching=True` to service methods (from 02-04)
- [x] Prompt caching uses `cache_control` ephemeral for transcripts > 500 words (from 02-04)
- [x] Logger warnings for marginal/poor quality transcripts
- [x] Cached responses also include quality warnings

## Deviations from Plan

None - plan executed exactly as written.

## Requirements Coverage

- **SUMM-09:** Users can regenerate poor summaries via `regenerate=true` flag
- **SUMM-10:** System warns about low-quality transcripts before summarization

## Next Phase Readiness

Phase 5 AI Summarization is now complete:
- Claude API foundation (05-01)
- Bullet summary generation (05-02)
- Pro fields and tier gating (05-03)
- Pro format generation (05-04)
- Quality detection and regeneration (05-05)

**Ready for remaining plans (05-06, 05-07) or Phase 6.**
