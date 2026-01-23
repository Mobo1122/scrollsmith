"""Video request/response schemas."""

from datetime import datetime
from typing import Literal, Optional, List, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


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
    user_edited_summary: bool = False
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


class UpdateSummaryRequest(BaseModel):
    """Request to manually update AI-generated video summary fields.

    All fields are optional - only provided fields will be updated.
    This allows partial updates (e.g., edit only tags, or only bullets).

    Note: This endpoint is for EDITING AI-generated summaries, not creating
    summaries from scratch. Users must generate summaries via POST /videos/{id}/summarize
    before they can edit them.

    Validation: The API validates the overall structure (array of objects with
    required fields) and returns clear error messages. Example error:
    {"detail": "Each step requires non-empty text"}
    """
    bullets: Optional[List[str]] = Field(
        None,
        min_length=1,
        max_length=15,
        description="Updated bullet points (3-15 bullets)"
    )
    tags: Optional[List[str]] = Field(
        None,
        max_length=10,
        description="Updated tags (up to 10 tags)"
    )
    steps: Optional[dict] = Field(
        None,
        description="Updated step checklist (must match StepChecklist schema structure)"
    )
    cards: Optional[dict] = Field(
        None,
        description="Updated cards (must match CardsSummary schema structure)"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "bullets": [
                    "Key insight 1",
                    "Key insight 2",
                    "Key insight 3"
                ],
                "tags": ["productivity", "habits", "mindset"]
            }
        }


class VideoSearchResult(BaseModel):
    """Single search result with highlight."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    source_url: Optional[str]
    summary_bullets: Optional[str]
    tags: Optional[List[str]]
    created_at: datetime
    rank: float  # Search relevance score
    highlight: Optional[str]  # Matched text with <mark> tags


class VideoSearchResponse(BaseModel):
    """Search results response."""
    videos: List[VideoSearchResult]
    query: str
    total: int


class VideoAssignPlaybookRequest(BaseModel):
    """Request to assign video to Playbook."""
    playbook_id: UUID


class VideoPlaybooksResponse(BaseModel):
    """Response listing Playbooks a video belongs to."""
    video_id: UUID
    playbook_ids: List[UUID]


class VideoUpdateTagsRequest(BaseModel):
    """Request to update video tags."""
    tags: List[str] = Field(..., max_length=20)  # Max 20 tags per video


class VideoUpdateTagsResponse(BaseModel):
    """Response after updating tags."""
    id: UUID
    tags: List[str]


# ============================================================
# Bulk Operations Schemas
# ============================================================


class BulkDeleteRequest(BaseModel):
    """Request to delete multiple videos at once.

    Maximum 100 videos per request to prevent excessive load.
    """

    video_ids: List[UUID] = Field(
        ...,
        min_length=1,
        max_length=100,
        description="List of video IDs to delete (1-100)",
    )


class BulkDeleteResponse(BaseModel):
    """Response after bulk delete operation.

    Returns the count of actually deleted videos and their IDs.
    Only videos owned by the user are deleted.
    """

    deleted_count: int = Field(description="Number of videos actually deleted")
    video_ids: List[UUID] = Field(description="IDs of deleted videos")


class BulkMoveRequest(BaseModel):
    """Request to move videos to a Playbook.

    Adds videos to the target Playbook. Videos can be in multiple
    Playbooks simultaneously (many-to-many relationship).
    """

    video_ids: List[UUID] = Field(
        ...,
        min_length=1,
        max_length=100,
        description="List of video IDs to move (1-100)",
    )
    playbook_id: UUID = Field(description="Target Playbook ID")


class BulkMoveResponse(BaseModel):
    """Response after bulk move operation.

    Returns the count of moved videos and the target Playbook.
    """

    moved_count: int = Field(description="Number of videos actually moved")
    playbook_id: UUID = Field(description="Target Playbook ID")
    video_ids: List[UUID] = Field(description="IDs of moved videos")


class BulkAddToFavoritesRequest(BaseModel):
    """Request to add videos to Favorites Playbook.

    Convenience schema for the add-to-favorites shortcut.
    """

    video_ids: List[UUID] = Field(
        ...,
        min_length=1,
        max_length=100,
        description="List of video IDs to add to Favorites (1-100)",
    )
