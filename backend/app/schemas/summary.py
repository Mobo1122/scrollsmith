"""Summary format schemas for Claude API structured outputs."""

from __future__ import annotations

from typing import Literal, Optional, List
from pydantic import BaseModel, Field


class BulletSummary(BaseModel):
    """Bullet-point summary format (free tier).

    Optimized for Claude Haiku 4.5 for cost efficiency.
    """
    bullets: list[str] = Field(
        min_length=3,
        max_length=10,
        description="3-10 concise bullet points summarizing key insights"
    )
    tags: list[str] = Field(
        max_length=8,
        description="Up to 8 relevant tags for categorization"
    )


class StepChecklistItem(BaseModel):
    """Individual step in a checklist."""
    step_number: int = Field(ge=1, description="Step sequence number")
    instruction: str = Field(min_length=10, description="Clear, actionable instruction")
    timestamp_seconds: Optional[int] = Field(
        None,
        ge=0,
        description="Timestamp in video where this step is mentioned (if identifiable)"
    )


class StepChecklist(BaseModel):
    """Step-by-step checklist with timestamps (Pro tier).

    Optimized for Claude Sonnet 4.5 for better instruction understanding.
    """
    title: str = Field(min_length=5, max_length=100)
    steps: list[StepChecklistItem] = Field(
        min_length=1,
        max_length=20,
        description="Sequential action steps"
    )
    estimated_duration_minutes: Optional[int] = Field(
        None,
        ge=1,
        description="Estimated time to complete all steps"
    )


class SwipeableCard(BaseModel):
    """Individual swipeable card."""
    title: str = Field(min_length=3, max_length=60)
    content: str = Field(min_length=10, max_length=300)
    category: Literal["tip", "warning", "insight", "action"] = Field(
        description="Card type for visual styling"
    )


class CardsSummary(BaseModel):
    """Swipeable cards format (Pro tier).

    Optimized for Claude Sonnet 4.5 for nuanced categorization.
    """
    cards: list[SwipeableCard] = Field(
        min_length=3,
        max_length=12,
        description="3-12 cards with key insights"
    )
