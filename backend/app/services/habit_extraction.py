"""Habit extraction service using Anthropic Claude API structured outputs.

Extracts 1-3 concrete, recurring habits from video transcripts using Claude Sonnet
with structured outputs for guaranteed valid JSON.

Exports:
    - HabitExtractionService: Main service class
    - habit_extraction_service: Singleton instance
    - HabitExtractionError: Base error class
    - NoAPIKeyError: Claude API not configured
    - ExtractionFailedError: Claude API call failed
    - TranscriptTooShortError: Transcript below minimum length
"""

from __future__ import annotations

import json
import logging
from typing import List, Optional

from anthropic import AsyncAnthropic, RateLimitError, APIStatusError
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential_jitter,
    retry_if_exception_type,
)

from app.core.config import settings
from app.schemas.habit import HabitSuggestion

logger = logging.getLogger(__name__)


# System prompt for habit extraction - constrains output to specific, actionable habits
HABIT_EXTRACTION_SYSTEM_PROMPT = """You are a habit extraction assistant. Your task is to identify 1-3 concrete, recurring habits from video transcripts.

Extract habits that are:
1. SPECIFIC: Concrete actions with clear completion criteria (e.g., "Do 20 pushups" not "exercise more")
2. RECURRING: Can be done daily, 3 times weekly, or weekly as a sustainable practice
3. DERIVED: Directly based on advice/techniques from the video content
4. ACTIONABLE: Phrased as verbs (e.g., "Write 3 gratitude items" not "Practice gratitude")

For each habit:
- title: Short, action-oriented title (5-100 chars)
- description: Brief explanation of why this habit matters, referencing the video content
- suggested_frequency: One of "daily", "3x_weekly", or "weekly" based on what makes sense

If the video doesn't contain actionable recurring advice, return fewer habits (minimum 1).
Never return generic self-help habits that aren't derived from the specific video content."""


class HabitExtractionError(Exception):
    """Base error for habit extraction service."""
    pass


class NoAPIKeyError(HabitExtractionError):
    """No Claude API key configured."""
    pass


class ExtractionFailedError(HabitExtractionError):
    """Claude API call failed."""
    pass


class TranscriptTooShortError(HabitExtractionError):
    """Transcript is too short for quality habit extraction."""
    pass


class HabitExtractionService:
    """Habit extraction service using Claude API with structured outputs.

    Uses Claude Sonnet 4.5 for better reasoning about actionable habits.
    Structured outputs guarantee valid JSON response.
    """

    def __init__(self, api_key: Optional[str] = None):
        """Initialize service with Claude API client.

        Args:
            api_key: Anthropic API key. If None, reads from ANTHROPIC_API_KEY env var.
        """
        self.api_key = api_key or settings.ANTHROPIC_API_KEY
        if not self.api_key:
            logger.warning("No ANTHROPIC_API_KEY configured for habit extraction")

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
            return await self.client.beta.messages.create(**kwargs)
        except RateLimitError:
            logger.warning("Claude API rate limit hit, retrying with backoff...")
            raise
        except APIStatusError as e:
            if e.status_code >= 500:
                logger.warning(f"Claude API server error {e.status_code}, retrying...")
                raise
            # Don't retry 4xx errors
            raise ExtractionFailedError(f"Claude API error: {e}")

    def _validate_transcript(self, transcript: str, min_words: int = 50) -> None:
        """Validate transcript length for quality habit extraction.

        Args:
            transcript: Transcript text to validate
            min_words: Minimum word count (default 50)

        Raises:
            TranscriptTooShortError: If transcript is too short
        """
        word_count = len(transcript.split())
        if word_count < min_words:
            raise TranscriptTooShortError(
                f"Transcript too short for habit extraction: {word_count} words (minimum {min_words})"
            )

    async def extract_habits(self, transcript: str) -> List[HabitSuggestion]:
        """Extract 1-3 habits from a video transcript.

        Uses Claude Sonnet 4.5 with structured outputs for guaranteed valid JSON.

        Args:
            transcript: Video transcript text

        Returns:
            List of 1-3 HabitSuggestion objects

        Raises:
            TranscriptTooShortError: If transcript < 50 words
            NoAPIKeyError: If ANTHROPIC_API_KEY not configured
            ExtractionFailedError: If Claude API call fails
        """
        # Validate transcript length
        self._validate_transcript(transcript, min_words=50)

        try:
            response = await self._call_claude(
                model="claude-sonnet-4-5-20250514",
                max_tokens=1024,
                betas=["structured-outputs-2025-11-13"],
                system=HABIT_EXTRACTION_SYSTEM_PROMPT,
                messages=[
                    {
                        "role": "user",
                        "content": f"Extract habits from this transcript:\n\n{transcript}"
                    }
                ],
                output_format={
                    "type": "json_schema",
                    "json_schema": {
                        "name": "habit_extraction",
                        "strict": True,
                        "schema": {
                            "type": "object",
                            "properties": {
                                "habits": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "title": {"type": "string"},
                                            "description": {"type": "string"},
                                            "suggested_frequency": {
                                                "type": "string",
                                                "enum": ["daily", "3x_weekly", "weekly"]
                                            }
                                        },
                                        "required": ["title", "description", "suggested_frequency"],
                                        "additionalProperties": False
                                    },
                                    "minItems": 1,
                                    "maxItems": 3
                                }
                            },
                            "required": ["habits"],
                            "additionalProperties": False
                        }
                    }
                }
            )

            # Parse JSON from response
            response_text = response.content[0].text
            parsed_data = json.loads(response_text)

            # Validate each habit against HabitSuggestion schema
            habits = [
                HabitSuggestion(**habit_data)
                for habit_data in parsed_data["habits"]
            ]

            logger.info(f"Extracted {len(habits)} habits from transcript")
            return habits

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse habit extraction response: {e}")
            raise ExtractionFailedError(f"Failed to parse extraction response: {e}")
        except Exception as e:
            logger.error(f"Habit extraction failed: {e}")
            raise ExtractionFailedError(f"Failed to extract habits: {str(e)}")


# Singleton instance
habit_extraction_service = HabitExtractionService()
