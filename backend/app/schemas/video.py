"""Video request/response schemas."""

from datetime import datetime
from typing import Literal, Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class YouTubeCaptionsRequest(BaseModel):
    """Request to fetch YouTube captions."""
    url: str = Field(..., description="YouTube video URL")


class YouTubeCaptionsResponse(BaseModel):
    """Response from YouTube captions endpoint."""
    success: bool
    video_id: Optional[UUID] = None  # Set if video record was created
    transcript: Optional[str] = None
    title: Optional[str] = None
    transcript_source: Optional[str] = None  # manual, auto, translated
    error: Optional[str] = None
    error_type: Optional[str] = None  # rate_limit, no_captions, unavailable, api_error


class VideoCreateRequest(BaseModel):
    """Request to create a video with transcript from iOS."""
    source_url: str = Field(..., description="Original video URL or local identifier")
    platform: str = Field(..., description="Video platform: tiktok, instagram, youtube, camera_roll")
    transcript: str = Field(..., description="Transcription text")
    title: Optional[str] = Field(None, description="Video title if available")
    duration_seconds: Optional[float] = Field(None, description="Video duration in seconds")


class VideoResponse(BaseModel):
    """Video entity response."""
    id: UUID
    source_url: Optional[str] = None
    transcript: Optional[str] = None
    summary_bullets: Optional[str] = None
    summary_steps: Optional[str] = None
    summary_cards: Optional[str] = None
    tags: Optional[List[str]] = None
    created_at: datetime

    class Config:
        from_attributes = True


class VideoListResponse(BaseModel):
    """List of videos response."""
    videos: List[VideoResponse]
    total: int


class SummarizeRequest(BaseModel):
    """Request to generate summary for a video."""
    format: Literal["bullets", "steps", "cards"] = Field(
        default="bullets",
        description="Summary format: bullets (free), steps/cards (Pro)"
    )
    regenerate: bool = Field(
        default=False,
        description="Force regeneration even if summary exists"
    )


class TranscriptQuality(BaseModel):
    """Transcript quality assessment."""
    quality: Literal["good", "marginal", "poor"]
    word_count: int
    warnings: List[str] = Field(default_factory=list)
    recommendation: Optional[str] = None


class SummarizeResponse(BaseModel):
    """Response from summarize endpoint."""
    video_id: UUID
    format: str
    cached: bool = Field(description="Whether this was retrieved from cache")
    summary: dict = Field(description="Summary content (structure depends on format)")
    tags: Optional[List[str]] = None
    transcript_quality: Optional[TranscriptQuality] = Field(
        None,
        description="Quality assessment of transcript (included if quality is marginal/poor)"
    )
