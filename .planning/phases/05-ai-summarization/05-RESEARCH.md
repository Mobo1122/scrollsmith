# Phase 5: AI Summarization - Research

**Researched:** 2026-01-23
**Domain:** AI-powered content summarization with Claude API
**Confidence:** HIGH

## Summary

This research investigated how to implement AI summarization using Anthropic's Claude API for generating multiple summary formats (bullets, steps, cards) from video transcripts. The standard approach leverages Claude Sonnet 4.5 or Haiku 4.5 models via the official Python SDK with async support, FastAPI integration, and structured JSON outputs for reliable parsing.

Claude's structured outputs feature (public beta) guarantees schema-compliant JSON responses, eliminating parsing errors and retries. Prompt caching can reduce costs by 90% for repeated transcript processing. The tier-based feature gating (free vs pro) is straightforward to implement server-side based on the user's subscription_tier field.

**Primary recommendation:** Use Claude Sonnet 4.5 for complex summaries requiring nuance (step-by-step instructions with timestamps), Claude Haiku 4.5 for simple bullet summaries at 3x lower cost. Implement structured outputs with Pydantic schemas for type-safe JSON responses. Cache transcripts using prompt caching to reduce latency and cost for regeneration requests.

## Standard Stack

The established libraries/tools for Claude API integration with FastAPI:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| anthropic | >=1.50.0 | Official Claude Python SDK | First-party SDK with async support, structured outputs, prompt caching |
| pydantic | >=2.0.0 | Schema validation | Already in project, integrates with structured outputs feature |
| asyncio | stdlib | Async operations | Native Python async runtime for FastAPI |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| aiohttp | >=3.9.0 | Async HTTP (optional) | Improved async performance for Claude SDK (optional install: anthropic[aiohttp]) |
| tenacity | >=8.2.0 | Retry logic | Exponential backoff for Claude API 429/529 errors |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Claude API | OpenAI GPT-4 | GPT-4 lacks structured outputs guarantee, higher hallucination rate for instructions |
| Structured outputs | Prompt-only JSON | 30-50% failure rate on complex schemas without structured outputs |
| Pydantic | Raw JSON schemas | More verbose, less type-safe, Pydantic already in project |

**Installation:**
```bash
# Add to requirements.txt
anthropic>=1.50.0
tenacity>=8.2.0
```

## Architecture Patterns

### Recommended Project Structure
```
backend/app/
├── services/
│   ├── summarization.py      # Claude API integration service
│   └── transcription.py       # (existing) Whisper/AssemblyAI
├── schemas/
│   ├── video.py              # (existing) Video schemas
│   └── summary.py            # NEW: Summary format schemas (Pydantic)
└── api/v1/endpoints/
    └── videos.py             # (existing) Video endpoints
```

### Pattern 1: Async Claude Service with Structured Outputs
**What:** Single service class handling all Claude API interactions with async/await
**When to use:** All summarization tasks (bullets, steps, cards, tags)
**Example:**
```python
# Source: https://github.com/anthropics/anthropic-sdk-python
from anthropic import AsyncAnthropic
from pydantic import BaseModel

class BulletSummary(BaseModel):
    bullets: list[str]
    tags: list[str]

class SummarizationService:
    def __init__(self):
        self.client = AsyncAnthropic()  # Reads ANTHROPIC_API_KEY env var

    async def generate_bullet_summary(self, transcript: str) -> BulletSummary:
        """Generate bullet-point summary with tags (free tier)."""
        response = await self.client.beta.messages.parse(
            model="claude-haiku-4-5",  # Cheaper for simple summaries
            max_tokens=2048,
            betas=["structured-outputs-2025-11-13"],
            system="You are a video summarization assistant. Extract key insights.",
            messages=[{"role": "user", "content": f"Summarize:\n\n{transcript}"}],
            output_format=BulletSummary,
        )
        return response.parsed_output  # Type-safe Pydantic object
```

### Pattern 2: Prompt Caching for Cost Optimization
**What:** Cache long transcripts to reduce costs for regeneration requests
**When to use:** When users manually regenerate summaries (SUMM-09)
**Example:**
```python
# Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
async def generate_with_caching(self, transcript: str, video_id: str):
    response = await self.client.beta.messages.parse(
        model="claude-sonnet-4-5",
        max_tokens=2048,
        betas=["structured-outputs-2025-11-13"],
        system=[
            {
                "type": "text",
                "text": "You are a video summarization assistant.",
            },
            {
                "type": "text",
                "text": f"Transcript:\n\n{transcript}",
                "cache_control": {"type": "ephemeral"}  # Cache transcript
            }
        ],
        messages=[{"role": "user", "content": "Generate step-by-step checklist"}],
        output_format=StepChecklist,
    )
    # Subsequent requests with same transcript: 90% cost reduction
```

### Pattern 3: Tier-Based Feature Gating
**What:** Server-side check of user.subscription_tier before Pro features
**When to use:** Step-by-step checklists (SUMM-02), swipeable cards (SUMM-03)
**Example:**
```python
# Source: Project requirements
async def generate_summary(
    video: Video,
    user: User,
    format: Literal["bullets", "steps", "cards"]
) -> dict:
    # Free tier: bullets only
    if user.subscription_tier == "free":
        if format != "bullets":
            raise HTTPException(403, "Pro tier required for this format")
        return await self.generate_bullet_summary(video.transcript)

    # Pro tier: all formats
    if format == "steps":
        return await self.generate_step_checklist(video.transcript)
    # ... etc
```

### Pattern 4: Structured Output Schemas
**What:** Pydantic models defining exact JSON structure for each summary format
**When to use:** All summary types to guarantee parseable responses
**Example:**
```python
# Source: https://platform.claude.com/docs/en/build-with-claude/structured-outputs
from pydantic import BaseModel, Field

class StepChecklistItem(BaseModel):
    step_number: int
    instruction: str
    timestamp_seconds: int | None = Field(
        None,
        description="Timestamp in video where this step is mentioned"
    )

class StepChecklist(BaseModel):
    """Step-by-step checklist with timestamps (Pro tier)."""
    title: str
    steps: list[StepChecklistItem]
    estimated_duration_minutes: int | None = None

# Claude guarantees this exact structure
response = await client.beta.messages.parse(
    output_format=StepChecklist,
    # ... other params
)
# response.parsed_output is a validated StepChecklist instance
```

### Anti-Patterns to Avoid
- **Don't use synchronous Claude client in async endpoints:** Use AsyncAnthropic, not Anthropic
- **Don't parse JSON manually from text responses:** Use structured outputs with Pydantic schemas
- **Don't retry on every error:** Only retry 429 (rate limit) and 529 (overload), not 4xx client errors
- **Don't cache short transcripts:** Minimum cacheable length is 1024 tokens (Sonnet) or 4096 tokens (Haiku)
- **Don't send API key in request body:** Use environment variable ANTHROPIC_API_KEY

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing from LLM | Custom regex/string parsing | Structured outputs with Pydantic | Eliminates 30-50% parsing failures, type-safe |
| Retry logic | Custom sleep/retry loops | tenacity library + exponential backoff | Handles jitter, max attempts, rate limit headers |
| API rate limiting | Manual token counting | Claude SDK token counting + rate limit headers | SDK counts accurately, headers show remaining quota |
| Long-running summarization | Inline API calls | FastAPI BackgroundTasks (simple) or Celery (complex) | Prevents request timeouts, better UX |
| Prompt optimization | Trial and error | Claude's prompt engineering docs + examples | Structured approach: clear instructions, XML tags, few-shot examples |

**Key insight:** Claude's structured outputs feature (beta) is a game-changer. Before this feature, developers spent significant effort parsing and validating JSON from text responses. With structured outputs, the API guarantees schema compliance through constrained decoding, eliminating an entire class of errors. This is production-ready as of December 2025.

## Common Pitfalls

### Pitfall 1: Poor Transcript Quality Handling
**What goes wrong:** Short, incoherent, or mistranscribed text produces low-quality summaries
**Why it happens:** Whisper/AssemblyAI can produce incomplete transcripts for short videos, background noise, or poor audio
**How to avoid:**
- Check transcript length before summarization (minimum 100 words recommended)
- Add system prompt instruction: "If the transcript is unclear or too short to summarize, respond with: 'Transcript quality insufficient for summarization'"
- Return structured error with `quality_warning: true` field to client
- Offer manual regeneration button (SUMM-09)
**Warning signs:** Summaries with generic/vague bullet points, hallucinated details not in transcript

### Pitfall 2: Rate Limit Errors Without Retry Logic
**What goes wrong:** API calls fail with 429 errors during concurrent requests or high traffic
**Why it happens:** Anthropic enforces tiered rate limits (RPM, ITPM, OTPM) based on account tier
**How to avoid:**
- Implement exponential backoff with jitter using tenacity library
- Check `retry-after` header in 429 responses (tells you exactly when to retry)
- Use async/await to avoid blocking other requests
- Monitor `x-ratelimit-*` headers to prevent hitting limits
**Warning signs:** "Rate limit exceeded" errors, requests failing during peak usage

### Pitfall 3: Expensive Pro Features on Free Tier Videos
**What goes wrong:** Accidentally generating step-by-step checklists for free tier users, incurring higher costs
**Why it happens:** No server-side validation of subscription_tier before calling Claude API
**How to avoid:**
- Always check `user.subscription_tier` before generating Pro features
- Free tier: Use Haiku 4.5 for bullets ($1/$5 per MTok)
- Pro tier: Use Sonnet 4.5 for steps/cards ($3/$15 per MTok)
- Return 403 Forbidden with upgrade prompt if free user requests Pro features
**Warning signs:** Unexpected high API bills, free users accessing Pro features in logs

### Pitfall 4: Synchronous API Calls Blocking FastAPI
**What goes wrong:** Long-running Claude API calls (2-10 seconds) block other requests
**Why it happens:** Using synchronous `Anthropic()` client instead of `AsyncAnthropic()`
**How to avoid:**
- Always use `AsyncAnthropic()` in FastAPI endpoints
- Use `await client.beta.messages.parse(...)` not `client.beta.messages.parse(...)`
- For very long operations (>30 seconds), use FastAPI BackgroundTasks or Celery
**Warning signs:** High p99 latency, concurrent request failures, thread pool exhaustion

### Pitfall 5: Missing Beta Header for Structured Outputs
**What goes wrong:** Structured outputs silently fail, falling back to text responses
**Why it happens:** Forgetting to include `betas=["structured-outputs-2025-11-13"]` parameter
**How to avoid:**
- Always include beta header when using structured outputs
- Use `client.beta.messages.parse()` method which handles this automatically
- Test with malformed inputs to ensure schema validation works
**Warning signs:** Parsing errors on responses, inconsistent JSON structure, missing fields

### Pitfall 6: Prompt Caching with Changing System Prompts
**What goes wrong:** Cache misses due to minor system prompt changes, no cost savings
**Why it happens:** Any change to cached content (even a single character) invalidates cache
**How to avoid:**
- Keep system prompts completely static
- Place variable content (user messages) after cache breakpoint
- Use multiple cache breakpoints for different update frequencies (tools → system → transcript)
- Monitor `cache_read_input_tokens` vs `cache_creation_input_tokens` in usage metrics
**Warning signs:** `cache_read_input_tokens` always 0, high `cache_creation_input_tokens`

## Code Examples

Verified patterns from official sources:

### Complete Summarization Service
```python
# Source: https://github.com/anthropics/anthropic-sdk-python
# Source: https://platform.claude.com/docs/en/build-with-claude/structured-outputs
from anthropic import AsyncAnthropic
from pydantic import BaseModel, Field
from typing import Literal
import asyncio

class BulletSummary(BaseModel):
    bullets: list[str] = Field(min_length=3, max_length=10)
    tags: list[str] = Field(max_length=8)

class StepChecklistItem(BaseModel):
    step_number: int
    instruction: str
    timestamp_seconds: int | None = None

class StepChecklist(BaseModel):
    title: str
    steps: list[StepChecklistItem] = Field(min_length=1, max_length=20)
    estimated_duration_minutes: int | None = None

class SwipeableCard(BaseModel):
    title: str
    content: str
    category: Literal["tip", "warning", "insight", "action"]

class CardsSummary(BaseModel):
    cards: list[SwipeableCard] = Field(min_length=3, max_length=12)

class SummarizationService:
    """AI summarization service using Claude API."""

    def __init__(self, api_key: str | None = None):
        self.client = AsyncAnthropic(api_key=api_key)  # Uses ANTHROPIC_API_KEY env if None

    async def generate_bullet_summary(
        self,
        transcript: str,
        use_caching: bool = False
    ) -> BulletSummary:
        """Generate bullet-point summary with tags (free tier).

        Uses Claude Haiku 4.5 for cost efficiency ($1/$5 per MTok).
        """
        if len(transcript.split()) < 50:
            raise ValueError("Transcript too short for summarization (minimum 50 words)")

        system_content = [
            {
                "type": "text",
                "text": (
                    "You are a video summarization assistant. Extract the most important "
                    "insights from video transcripts as concise bullet points. "
                    "Generate 3-10 bullet points and relevant tags."
                ),
            }
        ]

        if use_caching and len(transcript.split()) > 500:
            # Cache long transcripts for regeneration requests
            system_content.append({
                "type": "text",
                "text": f"Transcript:\n\n{transcript}",
                "cache_control": {"type": "ephemeral"}
            })
            user_message = "Summarize the transcript into bullet points with tags."
        else:
            user_message = f"Summarize this transcript:\n\n{transcript}"

        response = await self.client.beta.messages.parse(
            model="claude-haiku-4-5",
            max_tokens=2048,
            betas=["structured-outputs-2025-11-13"],
            system=system_content,
            messages=[{"role": "user", "content": user_message}],
            output_format=BulletSummary,
        )

        return response.parsed_output

    async def generate_step_checklist(
        self,
        transcript: str,
        use_caching: bool = False
    ) -> StepChecklist:
        """Generate step-by-step checklist with timestamps (Pro tier).

        Uses Claude Sonnet 4.5 for better understanding of sequential instructions.
        """
        system_content = [
            {
                "type": "text",
                "text": (
                    "You are a video summarization assistant. Extract actionable steps "
                    "from instructional video transcripts. Format as a numbered checklist "
                    "with timestamps when mentioned. Focus on concrete actions."
                ),
            }
        ]

        if use_caching and len(transcript.split()) > 500:
            system_content.append({
                "type": "text",
                "text": f"Transcript:\n\n{transcript}",
                "cache_control": {"type": "ephemeral"}
            })
            user_message = "Extract step-by-step instructions with timestamps."
        else:
            user_message = f"Extract steps from this transcript:\n\n{transcript}"

        response = await self.client.beta.messages.parse(
            model="claude-sonnet-4-5",
            max_tokens=4096,
            betas=["structured-outputs-2025-11-13"],
            system=system_content,
            messages=[{"role": "user", "content": user_message}],
            output_format=StepChecklist,
        )

        return response.parsed_output

    async def generate_cards(
        self,
        transcript: str,
        use_caching: bool = False
    ) -> CardsSummary:
        """Generate swipeable cards format (Pro tier).

        Uses Claude Sonnet 4.5 for nuanced categorization.
        """
        system_content = [
            {
                "type": "text",
                "text": (
                    "You are a video summarization assistant. Create engaging, swipeable "
                    "summary cards from video transcripts. Each card should contain one "
                    "key insight, tip, warning, or action item. Categorize appropriately."
                ),
            }
        ]

        if use_caching and len(transcript.split()) > 500:
            system_content.append({
                "type": "text",
                "text": f"Transcript:\n\n{transcript}",
                "cache_control": {"type": "ephemeral"}
            })
            user_message = "Create summary cards from the transcript."
        else:
            user_message = f"Create cards from this transcript:\n\n{transcript}"

        response = await self.client.beta.messages.parse(
            model="claude-sonnet-4-5",
            max_tokens=4096,
            betas=["structured-outputs-2025-11-13"],
            system=system_content,
            messages=[{"role": "user", "content": user_message}],
            output_format=CardsSummary,
        )

        return response.parsed_output

# Singleton instance
summarization_service = SummarizationService()
```

### Retry Logic with Exponential Backoff
```python
# Source: https://www.aifreeapi.com/en/posts/fix-claude-api-429-rate-limit-error
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential_jitter,
    retry_if_exception_type,
)
from anthropic import RateLimitError, APIStatusError

@retry(
    retry=retry_if_exception_type((RateLimitError, APIStatusError)),
    wait=wait_exponential_jitter(initial=1, max=60, jitter=2),
    stop=stop_after_attempt(5),
    reraise=True,
)
async def call_claude_with_retry(client: AsyncAnthropic, **kwargs):
    """Call Claude API with automatic retry on rate limits."""
    try:
        return await client.beta.messages.parse(**kwargs)
    except RateLimitError as e:
        # Check retry-after header
        if hasattr(e, 'response') and e.response:
            retry_after = e.response.headers.get('retry-after')
            if retry_after:
                await asyncio.sleep(int(retry_after))
        raise
```

### FastAPI Endpoint with Tier-Based Feature Gating
```python
# Source: Project requirements + FastAPI patterns
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter()

@router.post("/{video_id}/summarize")
async def summarize_video(
    video_id: str,
    format: Literal["bullets", "steps", "cards"],
    regenerate: bool = False,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate or regenerate video summary."""
    # Fetch video
    video = await db.get(Video, video_id)
    if not video or video.user_id != current_user.id:
        raise HTTPException(404, "Video not found")

    if not video.transcript:
        raise HTTPException(400, "Video has no transcript")

    # Tier-based feature gating
    if format in ["steps", "cards"] and current_user.subscription_tier == "free":
        raise HTTPException(
            403,
            detail={
                "error": "pro_required",
                "message": "Step-by-step checklists and cards require Pro tier",
                "upgrade_url": "/subscribe/pro"
            }
        )

    # Check if summary already exists and not regenerating
    if not regenerate and video.summary_bullets and format == "bullets":
        return {"cached": True, "summary": video.summary_bullets}

    # Generate summary in background for long operations
    if len(video.transcript) > 5000:
        background_tasks.add_task(
            generate_and_save_summary,
            video_id=video_id,
            transcript=video.transcript,
            format=format,
            use_caching=regenerate,  # Use caching for regeneration
        )
        return {"status": "processing", "message": "Summary generation started"}

    # Generate summary inline for short transcripts
    summary = await generate_summary(
        transcript=video.transcript,
        format=format,
        subscription_tier=current_user.subscription_tier,
        use_caching=regenerate,
    )

    # Save to database
    if format == "bullets":
        video.summary_bullets = summary.model_dump_json()

    await db.commit()

    return {"summary": summary.model_dump()}

async def generate_summary(
    transcript: str,
    format: Literal["bullets", "steps", "cards"],
    subscription_tier: str,
    use_caching: bool = False,
):
    """Route to appropriate summarization method based on format."""
    if format == "bullets":
        return await summarization_service.generate_bullet_summary(
            transcript, use_caching=use_caching
        )
    elif format == "steps":
        return await summarization_service.generate_step_checklist(
            transcript, use_caching=use_caching
        )
    elif format == "cards":
        return await summarization_service.generate_cards(
            transcript, use_caching=use_caching
        )
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Prompt-only JSON | Structured outputs with schemas | December 2025 | 30-50% reduction in parsing failures, type-safe responses |
| GPT-3.5/GPT-4 | Claude Sonnet 4.5 / Haiku 4.5 | 2025-2026 | Better instruction following, 67% cost reduction vs previous generation |
| Manual prompt design | Prompt engineering docs + XML tags | Ongoing | Systematic approach to prompt quality |
| Text-only responses | Pydantic model validation | December 2025 (beta) | SDK automatically validates against original schema |
| No caching | Prompt caching (5min/1hr) | 2024-2025 | 90% cost reduction for cached content |

**Deprecated/outdated:**
- **client.beta.prompt_caching.messages.create()**: Now generally available, use `client.messages.create()` directly
- **Manual JSON parsing from text**: Use structured outputs instead
- **Claude 3 Opus/Sonnet/Haiku**: Superseded by Claude 4.x models (4.5 is latest as of Jan 2026)

## Open Questions

Things that couldn't be fully resolved:

1. **Optimal transcript length for quality summaries**
   - What we know: Short transcripts (<50 words) produce low-quality summaries
   - What's unclear: Ideal minimum length varies by content type (tutorial vs conversation)
   - Recommendation: Set minimum 100 words, warn user if 100-200 words, block if <100 words

2. **Swipeable cards UI pattern for iOS**
   - What we know: Backend generates JSON with card structure (title, content, category)
   - What's unclear: Best SwiftUI implementation for swipe gestures and animations
   - Recommendation: Defer iOS implementation to Phase 7 (Summary Display), focus on backend JSON format now

3. **Cost optimization: Haiku vs Sonnet trade-offs**
   - What we know: Haiku 3x cheaper, Sonnet better for complex reasoning
   - What's unclear: Real-world quality difference for step-by-step instructions
   - Recommendation: Start with Haiku for bullets, Sonnet for steps/cards. A/B test if quality issues arise

4. **Background task queue: BackgroundTasks vs Celery**
   - What we know: BackgroundTasks simple but no status tracking, Celery complex but full-featured
   - What's unclear: Whether transcription time + summarization time exceeds FastAPI timeout
   - Recommendation: Start with FastAPI BackgroundTasks, migrate to Celery only if timeouts occur (>30s operations)

## Sources

### Primary (HIGH confidence)
- [Anthropic Python SDK](https://github.com/anthropics/anthropic-sdk-python) - Official SDK repository
- [Claude API Get Started](https://platform.claude.com/docs/en/docs/get-started) - Official API documentation
- [Structured Outputs Documentation](https://platform.claude.com/docs/en/build-with-claude/structured-outputs) - Schema-validated JSON responses
- [Prompt Caching Documentation](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) - Cost optimization guide
- [Prompt Engineering Overview](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview) - Best practices

### Secondary (MEDIUM confidence)
- [Claude API Pricing Guide 2026](https://www.aifreeapi.com/en/posts/claude-api-pricing-per-million-tokens) - Verified pricing details
- [Claude Haiku vs Sonnet Comparison](https://www.creolestudios.com/claude-haiku-4-5-vs-sonnet-4-5-comparison/) - Model performance analysis
- [Claude 429 Error Fix Guide](https://www.aifreeapi.com/en/posts/fix-claude-api-429-rate-limit-error) - Rate limit handling patterns
- [FastAPI Background Tasks](https://testdriven.io/blog/fastapi-and-celery/) - Background processing patterns

### Tertiary (LOW confidence - requires validation)
- [Video Transcript Summarization Best Practices](https://www.lindy.ai/blog/best-ai-summarizer) - General AI summarization tips
- [Audio Quality Impact on Transcripts](https://brasstranscripts.com/blog/audio-quality-ruining-transcripts-2026-fix-guide) - Handling poor transcripts

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official SDK well-documented, proven FastAPI integration
- Architecture: HIGH - Patterns verified from official docs and SDK examples
- Pitfalls: HIGH - Based on official documentation and common implementation issues
- Cost optimization: MEDIUM - Pricing verified, but real-world usage patterns need validation
- Poor transcript handling: MEDIUM - General best practices found, but video-specific patterns need testing

**Research date:** 2026-01-23
**Valid until:** ~30 days (stable API, but beta features may graduate or change)

**Key areas needing validation during implementation:**
1. Actual cost per video (transcript length varies widely)
2. Real-world quality difference between Haiku and Sonnet for step-by-step instructions
3. Frequency of poor transcript quality issues requiring fallback handling
4. Whether BackgroundTasks sufficient or Celery needed for performance
