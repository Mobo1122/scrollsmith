"""AI summarization service using Anthropic Claude API.

v1: Backend generates summaries using Claude Haiku (free tier bullets/tags)
and Claude Sonnet (Pro tier steps/cards).
"""

from __future__ import annotations

import logging
from typing import Optional

from anthropic import AsyncAnthropic, RateLimitError, APIStatusError
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential_jitter,
    retry_if_exception_type,
)

from app.core.config import settings
from app.schemas.summary import BulletSummary, StepChecklist, CardsSummary

logger = logging.getLogger(__name__)


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

        try:
            return await self.client.messages.create(**kwargs)
        except RateLimitError:
            logger.warning("Claude API rate limit hit, retrying with backoff...")
            raise
        except APIStatusError as e:
            if e.status_code >= 500:
                logger.warning(f"Claude API server error {e.status_code}, retrying...")
                raise
            # Don't retry 4xx errors
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
            BulletSummary with bullets and tags

        Raises:
            TranscriptTooShortError: If transcript < 50 words
            NoAPIKeyError: If ANTHROPIC_API_KEY not configured
            SummarizationFailedError: If Claude API call fails
        """
        # Validate transcript length
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
                model="claude-haiku-4-5-20241022",
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

                result = BulletSummary(
                    bullets=bullets[:10] if bullets else ["Summary could not be parsed"],
                    tags=tags[:8] if tags else ["video"]
                )

            logger.info(f"Generated bullet summary: {len(result.bullets)} bullets, {len(result.tags)} tags")
            return result

        except Exception as e:
            logger.error(f"Bullet summary generation failed: {e}")
            raise SummarizationFailedError(f"Failed to generate summary: {str(e)}")


# Singleton instance
summarization_service = SummarizationService()
