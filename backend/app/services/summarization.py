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


# Singleton instance
summarization_service = SummarizationService()
