"""AI summarization service using Anthropic Claude API.

v1: Backend generates summaries using Claude Haiku (free tier bullets/tags)
and Claude Sonnet (Pro tier steps/cards).
"""

from __future__ import annotations

import asyncio
from typing import Optional

from anthropic import AsyncAnthropic, RateLimitError, APIStatusError
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential_jitter,
    retry_if_exception_type,
)

from app.core.config import settings
from app.core.logging import get_logger
from app.schemas.summary import BulletSummary, StepChecklist, StepChecklistItem, CardsSummary, SwipeableCard

logger = get_logger(__name__)


class SummarizationError(Exception):
    """Base error for summarization service."""
    pass


class NoAPIKeyError(SummarizationError):
    """No Claude API key configured."""
    pass


class SummarizationFailedError(SummarizationError):
    """Claude API call failed."""
    pass


class TranscriptTooShortError(SummarizationError):
    """Transcript is too short for quality summarization."""
    pass


class SummarizationService:
    """AI summarization service using Claude API.

    Supports:
    - Bullet summaries with tags (free tier, Haiku 4.5)
    - Step-by-step checklists (Pro tier, Sonnet 4.5)
    - Swipeable cards (Pro tier, Sonnet 4.5)
    """

    def __init__(self, api_key: Optional[str] = None):
        """Initialize service with Claude API client.

        Args:
            api_key: Anthropic API key. If None, reads from ANTHROPIC_API_KEY env var.
        """
        self.api_key = api_key or settings.ANTHROPIC_API_KEY
        if not self.api_key:
            logger.warning("No ANTHROPIC_API_KEY configured")

        self.client = AsyncAnthropic(api_key=self.api_key) if self.api_key else None

    @property
    def is_available(self) -> bool:
        """Check if Claude API is configured."""
        return self.client is not None

    @retry(
        retry=retry_if_exception_type((RateLimitError, APIStatusError)),
        wait=wait_exponential_jitter(initial=1, max=60, jitter=2),
        stop=stop_after_attempt(5),
        reraise=True,
    )
    async def _call_claude(self, **kwargs):
        """Call Claude API with retry logic for rate limits.

        Retries on:
        - 429 (rate limit)
        - 529 (overload)

        Does NOT retry on 4xx client errors.
        """
        if not self.client:
            raise NoAPIKeyError(
                "Claude API not configured. Set ANTHROPIC_API_KEY environment variable."
            )

        model = kwargs.get("model", "unknown")
        logger.info("summarization_api_call_start", model=model)

        try:
            async with asyncio.timeout(30):
                response = await self.client.messages.create(**kwargs)
                logger.info("summarization_api_call_success", model=model)
                return response
        except asyncio.TimeoutError:
            logger.error("summarization_timeout", model=model, timeout_seconds=30)
            raise SummarizationFailedError("Claude API call timed out after 30 seconds")
        except RateLimitError:
            logger.warning("summarization_rate_limit", model=model)
            raise
        except APIStatusError as e:
            if e.status_code >= 500:
                logger.warning("summarization_server_error", model=model, status_code=e.status_code)
                raise
            # Don't retry 4xx errors
            logger.error("summarization_client_error", model=model, status_code=e.status_code, error=str(e))
            raise SummarizationFailedError(f"Claude API error: {e}")

    def _validate_transcript(self, transcript: str, min_words: int = 50) -> None:
        """Validate transcript length for quality summarization.

        Args:
            transcript: Transcript text to validate
            min_words: Minimum word count (default 50)

        Raises:
            TranscriptTooShortError: If transcript is too short
        """
        word_count = len(transcript.split())
        if word_count < min_words:
            raise TranscriptTooShortError(
                f"Transcript too short for summarization: {word_count} words (minimum {min_words})"
            )

    def check_transcript_quality(self, transcript: str) -> dict:
        """Check transcript quality and return warnings if needed.

        Quality indicators:
        - Word count (below 100 = too short, 100-200 = marginal, 200+ = good)
        - Average word length (very short words may indicate poor transcription)
        - Punctuation ratio (lack of punctuation suggests incoherent text)
        - Repetition patterns (high repetition = poor audio quality)

        Args:
            transcript: Transcript text to check

        Returns:
            Dict with quality assessment:
            {
                "quality": "good" | "marginal" | "poor",
                "word_count": int,
                "warnings": list[str],
                "recommendation": str | None
            }
        """
        words = transcript.split()
        word_count = len(words)

        warnings = []
        quality = "good"
        recommendation = None

        # Word count checks
        if word_count < 100:
            quality = "poor"
            warnings.append(f"Transcript is very short ({word_count} words)")
            recommendation = "Try a longer video or check audio quality"
        elif word_count < 200:
            quality = "marginal"
            warnings.append(f"Transcript is short ({word_count} words)")
            recommendation = "Summary quality may be limited"

        # Average word length (very short = potential transcription errors)
        if words:
            avg_word_length = sum(len(w) for w in words) / len(words)
            if avg_word_length < 3:
                quality = "marginal" if quality == "good" else "poor"
                warnings.append("Transcript contains many very short words (possible transcription errors)")

        # Punctuation check (coherent text should have some punctuation)
        punctuation_count = sum(1 for c in transcript if c in '.,!?;:')
        if word_count > 50 and punctuation_count < word_count * 0.01:  # Less than 1% punctuation
            quality = "marginal" if quality == "good" else "poor"
            warnings.append("Transcript lacks punctuation (may be incoherent)")

        # Repetition detection (simple: check if any 5-word phrase repeats 3+ times)
        if word_count > 50:
            phrases = [' '.join(words[i:i+5]) for i in range(len(words)-4)]
            phrase_counts: dict[str, int] = {}
            for phrase in phrases:
                phrase_counts[phrase] = phrase_counts.get(phrase, 0) + 1

            max_repetition = max(phrase_counts.values()) if phrase_counts else 0
            if max_repetition >= 3:
                quality = "marginal" if quality == "good" else "poor"
                warnings.append("High repetition detected (potential audio loop or poor quality)")

        return {
            "quality": quality,
            "word_count": word_count,
            "warnings": warnings,
            "recommendation": recommendation
        }

    def _fallback_bullet_summary(self, reason: str) -> BulletSummary:
        """Generate fallback bullet summary when LLM fails.

        Args:
            reason: Reason for fallback (timeout, API error, etc.)

        Returns:
            BulletSummary with error message
        """
        logger.warning("summarization_fallback_bullets", reason=reason)
        return BulletSummary(
            bullets=[
                "Summary temporarily unavailable",
                "Please try again in a few moments",
                f"Reason: {reason}",
            ],
            tags=["error", "retry-later"],
        )

    def _fallback_step_checklist(self, reason: str) -> StepChecklist:
        """Generate fallback step checklist when LLM fails.

        Args:
            reason: Reason for fallback (timeout, API error, etc.)

        Returns:
            StepChecklist with error message
        """
        logger.warning("summarization_fallback_steps", reason=reason)
        return StepChecklist(
            title="Checklist Unavailable",
            steps=[
                StepChecklistItem(
                    step_number=1,
                    instruction="Summary service is temporarily unavailable. Please try again in a few moments.",
                    timestamp_seconds=None
                )
            ],
            estimated_duration_minutes=None
        )

    def _fallback_cards(self, reason: str) -> CardsSummary:
        """Generate fallback cards summary when LLM fails.

        Args:
            reason: Reason for fallback (timeout, API error, etc.)

        Returns:
            CardsSummary with error message
        """
        logger.warning("summarization_fallback_cards", reason=reason)
        return CardsSummary(
            cards=[
                SwipeableCard(
                    title="Summary Unavailable",
                    content="The summary service is temporarily unavailable. Please try again in a few moments.",
                    category="insight"
                ),
                SwipeableCard(
                    title="What Happened",
                    content=f"Reason: {reason}",
                    category="insight"
                ),
                SwipeableCard(
                    title="Next Steps",
                    content="Wait a moment and try regenerating the summary.",
                    category="action"
                ),
            ]
        )

    async def generate_bullet_summary(
        self,
        transcript: str,
        use_caching: bool = False
    ) -> BulletSummary:
        """Generate bullet-point summary with tags (free tier).

        Uses Claude Haiku 4.5 for cost efficiency ($1/$5 per MTok input/output).

        Args:
            transcript: Video transcript text
            use_caching: Whether to use prompt caching (for regeneration)

        Returns:
            BulletSummary with bullets and tags (or fallback on LLM failure)

        Raises:
            TranscriptTooShortError: If transcript < 50 words (validation error)
            NoAPIKeyError: If ANTHROPIC_API_KEY not configured (validation error)
        """
        # Validate transcript length (still raise validation errors)
        self._validate_transcript(transcript, min_words=50)

        system_content = [
            {
                "type": "text",
                "text": (
                    "You are a video summarization assistant. Extract the most important "
                    "insights from video transcripts as concise bullet points. "
                    "Generate 3-10 bullet points capturing key takeaways. "
                    "Also generate 3-8 relevant tags for categorization (single words or short phrases)."
                ),
            }
        ]

        # Use prompt caching for long transcripts (regeneration optimization)
        if use_caching and len(transcript.split()) > 500:
            system_content.append({
                "type": "text",
                "text": f"Transcript:\n\n{transcript}",
                "cache_control": {"type": "ephemeral"}
            })
            user_message = "Summarize the transcript into bullet points with tags."
        else:
            user_message = f"Summarize this transcript into bullet points with tags:\n\n{transcript}"

        try:
            response = await self._call_claude(
                model="claude-3-haiku-20240307",
                max_tokens=2048,
                system=system_content,
                messages=[{"role": "user", "content": user_message}],
            )

            # Parse response into BulletSummary using Pydantic
            # Extract JSON from Claude response text
            import json
            import re

            response_text = response.content[0].text

            # Try to find JSON in the response
            json_match = re.search(r'\{[\s\S]*\}', response_text)
            if json_match:
                parsed_data = json.loads(json_match.group())
                result = BulletSummary(**parsed_data)
            else:
                # Fallback: parse structured text response
                lines = response_text.strip().split('\n')
                bullets = []
                tags = []
                in_tags = False

                for line in lines:
                    line = line.strip()
                    if line.lower().startswith('tags:') or line.lower().startswith('**tags'):
                        in_tags = True
                        # Extract tags from same line if present
                        tag_part = line.split(':', 1)[-1].strip()
                        if tag_part:
                            tags.extend([t.strip().strip('#') for t in tag_part.split(',') if t.strip()])
                    elif in_tags and line:
                        # Tags on separate lines
                        tags.extend([t.strip().strip('#-*') for t in line.split(',') if t.strip()])
                    elif line.startswith(('-', '*', '\u2022')) or (line and line[0].isdigit() and '.' in line[:3]):
                        # Bullet point
                        bullet = line.lstrip('-*\u2022 0123456789.').strip()
                        if bullet and not in_tags:
                            bullets.append(bullet)

                if not bullets:
                    # Last resort: treat each non-empty line as a bullet
                    bullets = [l.strip() for l in lines if l.strip() and not l.lower().startswith('tag')][:10]

                # Ensure minimum 3 bullets for BulletSummary validation
                if len(bullets) < 3:
                    bullets = bullets + ["Content could not be fully parsed"] * (3 - len(bullets))

                result = BulletSummary(
                    bullets=bullets[:10],
                    tags=tags[:8] if tags else ["video"]
                )

            logger.info("summarization_bullets_success", bullet_count=len(result.bullets), tag_count=len(result.tags))
            return result

        except (NoAPIKeyError, TranscriptTooShortError):
            # Re-raise validation errors (these should fail fast)
            raise
        except SummarizationFailedError as e:
            # LLM errors return fallback
            logger.error("summarization_bullets_failed", error=str(e))
            return self._fallback_bullet_summary(str(e))
        except Exception as e:
            logger.error("summarization_bullets_unexpected_error", error=str(e), error_type=type(e).__name__)
            return self._fallback_bullet_summary(f"Unexpected error: {type(e).__name__}")


    async def generate_step_checklist(
        self,
        transcript: str,
        use_caching: bool = False
    ) -> StepChecklist:
        """Generate step-by-step checklist with timestamps (Pro tier).

        Uses Claude Sonnet 4.5 for better understanding of sequential instructions
        and timestamp extraction.

        Args:
            transcript: Video transcript text
            use_caching: Whether to use prompt caching (for regeneration)

        Returns:
            StepChecklist with numbered steps and optional timestamps (or fallback on LLM failure)

        Raises:
            TranscriptTooShortError: If transcript < 50 words (validation error)
            NoAPIKeyError: If ANTHROPIC_API_KEY not configured (validation error)
        """
        self._validate_transcript(transcript, min_words=50)

        system_content = [
            {
                "type": "text",
                "text": (
                    "You are a video summarization assistant. Extract actionable steps "
                    "from instructional video transcripts. Format as a numbered checklist "
                    "with clear, concrete instructions. Include timestamps (in seconds) "
                    "when steps are explicitly mentioned in the transcript. If the video "
                    "includes time estimates, extract the total duration. Focus on "
                    "sequential, actionable steps that a user can follow."
                ),
            }
        ]

        if use_caching and len(transcript.split()) > 500:
            system_content.append({
                "type": "text",
                "text": f"Transcript:\n\n{transcript}",
                "cache_control": {"type": "ephemeral"}
            })
            user_message = "Extract step-by-step instructions with timestamps where mentioned."
        else:
            user_message = f"Extract actionable steps from this transcript:\n\n{transcript}"

        try:
            response = await self._call_claude(
                model="claude-sonnet-4-5-20250514",  # Sonnet for better reasoning
                max_tokens=4096,  # More tokens for detailed steps
                system=system_content,
                messages=[{"role": "user", "content": user_message}],
            )

            # Parse response into StepChecklist using Pydantic
            import json
            import re

            response_text = response.content[0].text

            # Try to find JSON in the response
            json_match = re.search(r'\{[\s\S]*\}', response_text)
            if json_match:
                parsed_data = json.loads(json_match.group())
                result = StepChecklist(**parsed_data)
            else:
                # Fallback: parse structured text response
                lines = response_text.strip().split('\n')
                steps = []
                title = "Step-by-Step Guide"

                for line in lines:
                    line = line.strip()
                    # Check for title
                    if line.startswith('#') or line.startswith('**') and len(steps) == 0:
                        title = line.strip('#* ').strip()
                        continue
                    # Check for numbered step
                    if line and (line[0].isdigit() or line.startswith('-') or line.startswith('*')):
                        step_text = line.lstrip('0123456789.-*) ').strip()
                        if step_text and len(step_text) >= 10:
                            steps.append(StepChecklistItem(
                                step_number=len(steps) + 1,
                                instruction=step_text,
                                timestamp_seconds=None
                            ))

                if not steps:
                    # Last resort: treat each line as a step
                    for i, line in enumerate(lines[:20], 1):
                        if line.strip() and len(line.strip()) >= 10:
                            steps.append(StepChecklistItem(
                                step_number=i,
                                instruction=line.strip(),
                                timestamp_seconds=None
                            ))

                result = StepChecklist(
                    title=title[:100] if title else "Step-by-Step Guide",
                    steps=steps[:20] if steps else [StepChecklistItem(step_number=1, instruction="Review the video content", timestamp_seconds=None)],
                    estimated_duration_minutes=None
                )

            logger.info("summarization_steps_success", step_count=len(result.steps))
            return result

        except (NoAPIKeyError, TranscriptTooShortError):
            # Re-raise validation errors (these should fail fast)
            raise
        except SummarizationFailedError as e:
            # LLM errors return fallback
            logger.error("summarization_steps_failed", error=str(e))
            return self._fallback_step_checklist(str(e))
        except Exception as e:
            logger.error("summarization_steps_unexpected_error", error=str(e), error_type=type(e).__name__)
            return self._fallback_step_checklist(f"Unexpected error: {type(e).__name__}")

    async def generate_cards(
        self,
        transcript: str,
        use_caching: bool = False
    ) -> CardsSummary:
        """Generate swipeable cards format (Pro tier).

        Uses Claude Sonnet 4.5 for nuanced categorization into tips, warnings,
        insights, and actions.

        Args:
            transcript: Video transcript text
            use_caching: Whether to use prompt caching (for regeneration)

        Returns:
            CardsSummary with 3-12 categorized cards (or fallback on LLM failure)

        Raises:
            TranscriptTooShortError: If transcript < 50 words (validation error)
            NoAPIKeyError: If ANTHROPIC_API_KEY not configured (validation error)
        """
        self._validate_transcript(transcript, min_words=50)

        system_content = [
            {
                "type": "text",
                "text": (
                    "You are a video summarization assistant. Create engaging, swipeable "
                    "summary cards from video transcripts. Each card should contain one "
                    "key insight, tip, warning, or action item. "
                    "\n\n"
                    "Card categories:\n"
                    "- tip: Helpful advice or best practice\n"
                    "- warning: Caution, common mistake, or pitfall to avoid\n"
                    "- insight: Key learning, revelation, or understanding\n"
                    "- action: Specific action item or next step\n"
                    "\n"
                    "Keep cards concise (max 300 characters) and ADHD-friendly. "
                    "Aim for 3-12 cards depending on content richness. "
                    "Return as JSON with format: {\"cards\": [{\"title\": \"...\", \"content\": \"...\", \"category\": \"tip|warning|insight|action\"}, ...]}"
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
            user_message = f"Create engaging summary cards from this transcript:\n\n{transcript}"

        try:
            response = await self._call_claude(
                model="claude-sonnet-4-5-20250514",  # Sonnet for better categorization
                max_tokens=4096,
                system=system_content,
                messages=[{"role": "user", "content": user_message}],
            )

            # Parse response into CardsSummary using Pydantic
            import json
            import re

            response_text = response.content[0].text

            # Try to find JSON in the response
            json_match = re.search(r'\{[\s\S]*\}', response_text)
            if json_match:
                parsed_data = json.loads(json_match.group())
                result = CardsSummary(**parsed_data)
            else:
                # Fallback: parse structured text response
                lines = response_text.strip().split('\n')
                cards = []
                current_card = {"title": "", "content": "", "category": "insight"}

                for line in lines:
                    line = line.strip()
                    if not line:
                        if current_card["title"] and current_card["content"]:
                            cards.append(SwipeableCard(**current_card))
                            current_card = {"title": "", "content": "", "category": "insight"}
                        continue

                    # Detect category keywords
                    lower_line = line.lower()
                    if 'tip:' in lower_line or lower_line.startswith('tip'):
                        current_card["category"] = "tip"
                    elif 'warning:' in lower_line or lower_line.startswith('warning'):
                        current_card["category"] = "warning"
                    elif 'action:' in lower_line or lower_line.startswith('action'):
                        current_card["category"] = "action"
                    elif 'insight:' in lower_line or lower_line.startswith('insight'):
                        current_card["category"] = "insight"

                    # Check for title (bold or heading)
                    if line.startswith('**') or line.startswith('#'):
                        title = line.strip('#* ').strip(':')
                        if title and len(title) <= 60:
                            current_card["title"] = title[:60]
                    elif not current_card["title"] and len(line) <= 60:
                        current_card["title"] = line[:60]
                    else:
                        if current_card["content"]:
                            current_card["content"] += " " + line
                        else:
                            current_card["content"] = line

                # Don't forget last card
                if current_card["title"] and current_card["content"]:
                    cards.append(SwipeableCard(**current_card))

                if not cards:
                    # Last resort: create cards from lines
                    for i, line in enumerate(lines[:12]):
                        if line.strip() and len(line.strip()) >= 10:
                            cards.append(SwipeableCard(
                                title=f"Insight {i+1}",
                                content=line.strip()[:300],
                                category="insight"
                            ))

                result = CardsSummary(
                    cards=cards[:12] if len(cards) >= 3 else [
                        SwipeableCard(title="Key Takeaway", content="Review the video for main insights", category="insight"),
                        SwipeableCard(title="Action Item", content="Apply the learnings from this video", category="action"),
                        SwipeableCard(title="Remember", content="Practice makes perfect", category="tip"),
                    ]
                )

            logger.info("summarization_cards_success", card_count=len(result.cards))
            return result

        except (NoAPIKeyError, TranscriptTooShortError):
            # Re-raise validation errors (these should fail fast)
            raise
        except SummarizationFailedError as e:
            # LLM errors return fallback
            logger.error("summarization_cards_failed", error=str(e))
            return self._fallback_cards(str(e))
        except Exception as e:
            logger.error("summarization_cards_unexpected_error", error=str(e), error_type=type(e).__name__)
            return self._fallback_cards(f"Unexpected error: {type(e).__name__}")


# Singleton instance
summarization_service = SummarizationService()
