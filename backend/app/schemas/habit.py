"""Pydantic schemas for habit extraction and management.

Exports:
    - HabitSuggestion: A single habit suggestion from Claude
    - HabitExtractionResponse: Response from extraction endpoint
    - HabitCreateRequest: Request to create a habit
    - HabitResponse: Full habit response
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class HabitSuggestion(BaseModel):
    """A single habit suggestion extracted from video content."""

    title: str = Field(
        min_length=5,
        max_length=100,
        description="Short, actionable habit title"
    )
    description: str = Field(
        max_length=300,
        description="Why this habit matters based on video content"
    )
    suggested_frequency: Literal["daily", "3x_weekly", "weekly"] = Field(
        description="Suggested frequency: 'daily', '3x_weekly', or 'weekly'"
    )


class HabitExtractionResponse(BaseModel):
    """Response from habit extraction endpoint."""

    video_id: UUID = Field(description="Video the habits were extracted from")
    suggestions: List[HabitSuggestion] = Field(
        min_length=1,
        max_length=3,
        description="1-3 habit suggestions"
    )


class HabitCreateRequest(BaseModel):
    """Request to create a habit from a suggestion."""

    video_id: UUID = Field(description="Source video for the habit")
    title: str = Field(
        min_length=1,
        max_length=200,
        description="Habit title"
    )
    frequency: Literal["daily", "3x_weekly", "weekly"] = Field(
        description="Chosen frequency for the habit"
    )


class HabitResponse(BaseModel):
    """Full habit response with tracking data."""

    id: UUID = Field(description="Habit ID")
    video_id: Optional[UUID] = Field(
        None,
        description="Source video ID (optional, habit may be created without video)"
    )
    title: str = Field(description="Habit title")
    frequency: str = Field(description="Habit frequency")
    current_streak: int = Field(
        default=0,
        ge=0,
        description="Current streak count"
    )
    longest_streak: int = Field(
        default=0,
        ge=0,
        description="Longest streak achieved"
    )
    created_at: datetime = Field(description="When the habit was created")

    model_config = {"from_attributes": True}
