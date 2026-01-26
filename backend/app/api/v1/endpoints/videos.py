"""Video processing endpoints.

v1: Server-side transcription for camera roll uploads, YouTube caption fetching.
TikTok/Instagram URL support deferred to v2 (requires WhisperKit on iOS).
"""

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from dateutil.relativedelta import relativedelta
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy import select, func, text, delete as sa_delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.models import User, Video, Playbook
from app.schemas.video import (
    YouTubeCaptionsRequest,
    YouTubeCaptionsResponse,
    VideoCreateRequest,
    VideoResponse,
    VideoListResponse,
    SummarizeRequest,
    SummarizeResponse,
    TranscriptQuality,
    UpdateSummaryRequest,
    VideoSearchResult,
    VideoSearchResponse,
    VideoAssignPlaybookRequest,
    VideoPlaybooksResponse,
    VideoUpdateTagsRequest,
    VideoUpdateTagsResponse,
    BulkDeleteRequest,
    BulkDeleteResponse,
    BulkMoveRequest,
    BulkMoveResponse,
    BulkAddToFavoritesRequest,
)
from app.schemas.summary import BulletSummary, StepChecklist, CardsSummary
from app.services.youtube_captions import (
    youtube_captions_service,
    YouTubeCaptionsError,
    RateLimitError,
    NoCaptionsError,
    VideoUnavailableError,
)
from app.services.transcription import (
    transcription_service,
    TranscriptionError,
    NoAPIKeyError as TranscriptionNoAPIKeyError,
    TranscriptionFailedError,
)
from app.services.summarization import (
    summarization_service,
    SummarizationError,
    NoAPIKeyError as SummarizationNoAPIKeyError,
    TranscriptTooShortError,
    SummarizationFailedError,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/videos", tags=["videos"])


# ============================================================
# Usage Limit Helpers
# ============================================================


def _get_next_reset_date() -> datetime:
    """Calculate the 1st of next month at midnight UTC."""
    now = datetime.now(timezone.utc)
    return (now + relativedelta(months=1)).replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def _check_and_reset_usage(user: User) -> None:
    """Reset usage counter if past reset date (in-place mutation)."""
    if user.subscription_tier == "pro":
        return

    now = datetime.now(timezone.utc)

    # Initialize reset date if not set
    if user.usage_reset_date is None:
        user.usage_reset_date = _get_next_reset_date()
        return

    # Reset if past reset date
    if now >= user.usage_reset_date:
        user.videos_this_month = 0
        user.usage_reset_date = _get_next_reset_date()
        logger.info(f"Reset usage for user {user.id}")


def _enforce_usage_limit(user: User) -> None:
    """Check if user has exceeded their video limit.

    Raises HTTPException 403 if free user has reached 10 videos/month.
    Pro users are unlimited.
    """
    if user.subscription_tier == "pro":
        return  # Pro users have unlimited videos

    _check_and_reset_usage(user)

    if user.videos_this_month >= settings.FREE_TIER_VIDEO_LIMIT:
        logger.info(f"User {user.id} blocked: {user.videos_this_month}/{settings.FREE_TIER_VIDEO_LIMIT} videos")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "usage_limit_exceeded",
                "message": f"You've reached your monthly limit of {settings.FREE_TIER_VIDEO_LIMIT} videos. Upgrade to Pro for unlimited videos.",
                "videos_this_month": user.videos_this_month,
                "videos_limit": settings.FREE_TIER_VIDEO_LIMIT,
                "upgrade_url": "/subscribe/pro",
            }
        )


def _increment_usage(user: User) -> None:
    """Increment usage counter for free users after successful video creation."""
    if user.subscription_tier != "pro":
        user.videos_this_month += 1
        logger.info(f"User {user.id} usage: {user.videos_this_month}/{settings.FREE_TIER_VIDEO_LIMIT}")


# ============================================================
# Video Endpoints
# ============================================================


@router.post("/transcribe", response_model=VideoResponse, status_code=status.HTTP_201_CREATED)
async def transcribe_audio(
    audio: UploadFile = File(..., description="Audio file to transcribe (M4A, MP3, WAV)"),
    platform: str = Form("camera_roll", description="Video source platform"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Video:
    """Upload audio file for server-side transcription.

    v1: Primary path for camera roll uploads.
    iOS extracts audio from video and uploads for transcription.
    Backend transcribes via Whisper API or AssemblyAI and deletes file immediately.

    Args:
        audio: Audio file (M4A, MP3, WAV)
        platform: Source platform (camera_roll, etc.)

    Returns:
        Video record with transcript

    Raises:
        403: Free tier limit exceeded
    """
    # Check usage limits before processing
    _enforce_usage_limit(current_user)

    # Validate file type
    allowed_types = ["audio/m4a", "audio/x-m4a", "audio/mp4", "audio/mpeg", "audio/wav", "audio/x-wav"]
    content_type = audio.content_type or ""

    # Also check file extension as fallback
    filename = audio.filename or "audio.m4a"
    allowed_extensions = [".m4a", ".mp3", ".wav", ".mp4", ".aac"]
    file_ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    if content_type not in allowed_types and file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported audio format: {content_type or file_ext}. Supported: M4A, MP3, WAV"
        )

    # Check if transcription service is available
    if not transcription_service.is_available:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Transcription service not configured. Contact support."
        )

    try:
        # Read audio data
        audio_data = await audio.read()

        if len(audio_data) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Empty audio file"
            )

        # Limit file size (50MB max)
        max_size = 50 * 1024 * 1024
        if len(audio_data) > max_size:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Audio file too large. Maximum size: {max_size // (1024*1024)}MB"
            )

        logger.info(f"Transcribing audio for user {current_user.id}: {len(audio_data)} bytes")

        # Transcribe
        transcript, metadata = await transcription_service.transcribe(audio_data, filename)

        # Create Video record
        video = Video(
            user_id=current_user.id,
            source_url=f"camera_roll://{filename}",
            transcript=transcript,
        )
        db.add(video)

        # Increment usage counter for free users
        _increment_usage(current_user)

        await db.commit()
        await db.refresh(video)

        logger.info(
            f"Created video {video.id} for user {current_user.id} "
            f"via {metadata.get('service', 'unknown')} transcription"
        )

        return video

    except TranscriptionNoAPIKeyError as e:
        logger.error(f"Transcription API not configured: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Transcription service not configured"
        )

    except TranscriptionFailedError as e:
        logger.error(f"Transcription failed for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Transcription failed: {str(e)}"
        )

    except TranscriptionError as e:
        logger.error(f"Transcription error for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/youtube-captions", response_model=YouTubeCaptionsResponse)
async def get_youtube_captions(
    request: YouTubeCaptionsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> YouTubeCaptionsResponse:
    """Fetch captions for a YouTube video.

    v1: Returns captions if available. If no captions, returns error.
    v2 TODO: Add fallback to on-device WhisperKit transcription.

    Raises:
        403: Free tier limit exceeded
    """
    # Check usage limits before processing
    _enforce_usage_limit(current_user)

    try:
        caption_text, metadata = await youtube_captions_service.get_captions(request.url)

        # Create Video record with transcript
        video = Video(
            user_id=current_user.id,
            source_url=request.url,
            transcript=caption_text,
        )
        db.add(video)

        # Increment usage counter for free users
        _increment_usage(current_user)

        await db.commit()
        await db.refresh(video)

        return YouTubeCaptionsResponse(
            success=True,
            video_id=video.id,
            transcript=caption_text,
            title=metadata.get('title'),
            transcript_source=metadata.get('transcript_source'),
        )

    except RateLimitError:
        # v1: No fallback - just report error
        # TODO v2: Signal iOS to use on-device WhisperKit fallback
        return YouTubeCaptionsResponse(
            success=False,
            error="YouTube rate limit exceeded. Please try again later.",
            error_type="rate_limit",
        )

    except NoCaptionsError as e:
        # v1: No fallback - report unavailable
        return YouTubeCaptionsResponse(
            success=False,
            error=str(e),
            error_type="no_captions",
        )

    except VideoUnavailableError as e:
        return YouTubeCaptionsResponse(
            success=False,
            error=str(e),
            error_type="unavailable",
        )

    except YouTubeCaptionsError as e:
        logger.error(f"YouTube captions error: {e}")
        return YouTubeCaptionsResponse(
            success=False,
            error=str(e),
            error_type="api_error",
        )


@router.post("", response_model=VideoResponse, status_code=status.HTTP_201_CREATED)
async def create_video(
    request: VideoCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Video:
    """Create a video record with transcript from iOS.

    v2 TODO: Used for on-device transcription results from WhisperKit.

    Raises:
        403: Free tier limit exceeded
    """
    # Check usage limits before processing
    _enforce_usage_limit(current_user)

    video = Video(
        user_id=current_user.id,
        source_url=request.source_url,
        transcript=request.transcript,
    )
    db.add(video)

    # Increment usage counter for free users
    _increment_usage(current_user)

    await db.commit()
    await db.refresh(video)

    logger.info(f"Created video {video.id} for user {current_user.id} from {request.platform}")

    return video


@router.post("/{video_id}/summarize", response_model=SummarizeResponse)
async def summarize_video(
    video_id: UUID,
    request: SummarizeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SummarizeResponse:
    """Generate AI summary for a video.

    v1: Supports bullets format for all users (free tier).
    Pro formats (steps, cards) require Pro subscription.

    Args:
        video_id: Video to summarize
        request: Summary options (format, regenerate flag)

    Returns:
        Generated or cached summary

    Raises:
        404: Video not found or not owned by user
        400: Video has no transcript
        403: Pro format requested by free user
        501: Pro format generation not yet implemented
        503: Claude API not configured
        500: Summarization failed
    """
    import json

    # Check if Claude API is configured
    if not summarization_service.is_available:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI summarization service not configured. Contact support."
        )

    # Fetch video
    result = await db.execute(
        select(Video).where(
            Video.id == video_id,
            Video.user_id == current_user.id
        )
    )
    video = result.scalar_one_or_none()

    if video is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found"
        )

    if not video.transcript:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Video has no transcript. Transcription must complete first."
        )

    # Check transcript quality and warn if marginal
    quality_info = summarization_service.check_transcript_quality(video.transcript)
    quality_warning = None

    if quality_info["quality"] in ["marginal", "poor"]:
        quality_warning = TranscriptQuality(**quality_info)
        logger.warning(
            f"Video {video_id} has {quality_info['quality']} transcript quality: "
            f"{quality_info['warnings']}"
        )

    # Poor quality transcripts are blocked by _validate_transcript in service
    # Marginal quality transcripts proceed with warning

    # Tier-based feature gating for Pro formats
    if request.format in ["steps", "cards"]:
        if current_user.subscription_tier == "free":
            logger.info(f"Free user {current_user.id} attempted Pro format '{request.format}'")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "pro_required",
                    "message": f"{request.format.capitalize()} format requires Pro subscription",
                    "upgrade_url": "/subscribe/pro",  # TODO Phase 8: Replace with actual upgrade URL
                    "format_requested": request.format
                }
            )

    # Check if summary already exists (and not regenerating)
    # User-edited summaries are ALWAYS returned from cache unless regenerate=true
    # This protects user modifications from being accidentally overwritten
    if not request.regenerate:
        cached_data = None
        tags = None

        if video.user_edited_summary:
            logger.info(f"Returning user-edited summary for video {video_id} (use regenerate=true to overwrite)")

        if request.format == "bullets" and video.summary_bullets and video.tags:
            cached_data = json.loads(video.summary_bullets)
            tags = video.tags
        elif request.format == "steps" and video.summary_steps:
            cached_data = json.loads(video.summary_steps)
            tags = video.tags  # Tags from bullets (always generated first)
        elif request.format == "cards" and video.summary_cards:
            cached_data = json.loads(video.summary_cards)
            tags = video.tags

        if cached_data:
            logger.info(f"Returning cached {request.format} summary for video {video_id}")
            return SummarizeResponse(
                video_id=video.id,
                format=request.format,
                cached=True,
                summary=cached_data,
                tags=tags,
                transcript_quality=quality_warning,
            )

    # Generate summary based on format
    try:
        logger.info(f"Generating {request.format} summary for video {video_id}")

        # Clear user_edited flag when regenerating (user explicitly requested new AI summary)
        if request.regenerate and video.user_edited_summary:
            logger.info(f"Clearing user_edited flag for video {video_id} (regenerate=true)")
            video.user_edited_summary = False

        if request.format == "bullets":
            summary = await summarization_service.generate_bullet_summary(
                transcript=video.transcript,
                use_caching=request.regenerate,
            )

            # Save to database
            video.summary_bullets = summary.model_dump_json()
            video.tags = summary.tags
            await db.commit()
            await db.refresh(video)

            logger.info(f"Saved bullet summary for video {video_id}: {len(summary.bullets)} bullets, {len(summary.tags)} tags")

            return SummarizeResponse(
                video_id=video.id,
                format="bullets",
                cached=False,
                summary=summary.model_dump(),
                tags=summary.tags,
                transcript_quality=quality_warning,
            )

        elif request.format == "steps":
            summary = await summarization_service.generate_step_checklist(
                transcript=video.transcript,
                use_caching=request.regenerate,
            )
            video.summary_steps = summary.model_dump_json()
            # Tags come from bullets (generate bullets first if not present)
            if not video.tags:
                logger.info("Generating tags alongside steps (bullets not yet generated)")
                bullets = await summarization_service.generate_bullet_summary(
                    transcript=video.transcript,
                    use_caching=False,
                )
                video.summary_bullets = bullets.model_dump_json()
                video.tags = bullets.tags
            summary_dict = summary.model_dump()
            tags = video.tags

            await db.commit()
            await db.refresh(video)

            logger.info(f"Saved steps summary for video {video_id}: {len(summary.steps)} steps")

            return SummarizeResponse(
                video_id=video.id,
                format=request.format,
                cached=False,
                summary=summary_dict,
                tags=tags,
                transcript_quality=quality_warning,
            )

        elif request.format == "cards":
            summary = await summarization_service.generate_cards(
                transcript=video.transcript,
                use_caching=request.regenerate,
            )
            video.summary_cards = summary.model_dump_json()
            # Tags come from bullets
            if not video.tags:
                logger.info("Generating tags alongside cards (bullets not yet generated)")
                bullets = await summarization_service.generate_bullet_summary(
                    transcript=video.transcript,
                    use_caching=False,
                )
                video.summary_bullets = bullets.model_dump_json()
                video.tags = bullets.tags
            summary_dict = summary.model_dump()
            tags = video.tags

            await db.commit()
            await db.refresh(video)

            logger.info(f"Saved cards summary for video {video_id}: {len(summary.cards)} cards")

            return SummarizeResponse(
                video_id=video.id,
                format=request.format,
                cached=False,
                summary=summary_dict,
                tags=tags,
                transcript_quality=quality_warning,
            )

    except TranscriptTooShortError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

    except SummarizationNoAPIKeyError:
        logger.error("Claude API not configured")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI summarization service not configured"
        )

    except SummarizationFailedError as e:
        logger.error(f"Summarization failed for video {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Summarization failed: {str(e)}"
        )

    except SummarizationError as e:
        logger.error(f"Summarization error for video {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.patch("/{video_id}/summary", response_model=VideoResponse)
async def update_summary(
    video_id: UUID,
    request: UpdateSummaryRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Video:
    """Manually update AI-generated video summary fields.

    Allows users to edit AI-generated summaries and tags. Supports partial
    updates - only provided fields will be modified.

    **Important behavior:**
    - Sets user_edited_summary=True to protect edits from auto-regeneration
    - POST /summarize with regenerate=false will return cached (edited) summary
    - POST /summarize with regenerate=true will overwrite edits and clear flag

    Note: This endpoint edits existing AI-generated summaries. To generate
    summaries initially, use POST /videos/{id}/summarize.

    Args:
        video_id: Video to update
        request: Fields to update (all optional)

    Returns:
        Updated video record

    Raises:
        404: Video not found or not owned by user
        400: Invalid summary structure (steps/cards don't match schema)
    """
    import json

    # Fetch video
    result = await db.execute(
        select(Video).where(
            Video.id == video_id,
            Video.user_id == current_user.id
        )
    )
    video = result.scalar_one_or_none()

    if video is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found"
        )

    # Track which fields are being updated
    updates = []

    # Update bullets (stored as JSON with tags)
    if request.bullets is not None:
        if len(request.bullets) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bullets must contain at least 3 items"
            )

        # Reconstruct BulletSummary structure
        bullet_summary = BulletSummary(
            bullets=request.bullets,
            tags=request.tags if request.tags is not None else video.tags or []
        )
        video.summary_bullets = bullet_summary.model_dump_json()
        video.tags = bullet_summary.tags
        updates.append("bullets")

    # Update tags independently (if bullets not updated)
    elif request.tags is not None:
        video.tags = request.tags
        # Also update bullets JSON if it exists (to keep tags in sync)
        if video.summary_bullets:
            bullet_data = json.loads(video.summary_bullets)
            bullet_data["tags"] = request.tags
            video.summary_bullets = json.dumps(bullet_data)
        updates.append("tags")

    # Update step checklist (Pro tier) with schema validation
    if request.steps is not None:
        try:
            # Validate against StepChecklist schema
            step_checklist = StepChecklist(**request.steps)
            video.summary_steps = step_checklist.model_dump_json()
            updates.append("steps")
        except Exception as e:
            # Return clear error message for schema validation failures
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Each step requires non-empty text: {str(e)}"
            )

    # Update cards (Pro tier) with schema validation
    if request.cards is not None:
        try:
            # Validate against CardsSummary schema
            cards_summary = CardsSummary(**request.cards)
            video.summary_cards = cards_summary.model_dump_json()
            updates.append("cards")
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid cards structure: {str(e)}"
            )

    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update. Provide at least one field: bullets, tags, steps, or cards."
        )

    # Mark as user-edited to prevent auto-regeneration
    video.user_edited_summary = True

    # Save changes
    await db.commit()
    await db.refresh(video)

    logger.info(f"Updated summary for video {video_id}: {', '.join(updates)} (user_edited=True)")

    return video


@router.post("/{video_id}/playbooks", response_model=VideoPlaybooksResponse, status_code=status.HTTP_201_CREATED)
async def assign_video_to_playbook(
    video_id: UUID,
    request: VideoAssignPlaybookRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VideoPlaybooksResponse:
    """Assign a video to a Playbook.

    Videos can belong to multiple Playbooks (many-to-many).
    """
    # Verify video exists and belongs to user
    video_result = await db.execute(
        select(Video).where(Video.id == video_id, Video.user_id == current_user.id)
    )
    video = video_result.scalar_one_or_none()
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    # Verify Playbook exists and belongs to user
    playbook_result = await db.execute(
        select(Playbook).where(Playbook.id == request.playbook_id, Playbook.user_id == current_user.id)
    )
    playbook = playbook_result.scalar_one_or_none()
    if playbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Playbook not found")

    # Add association (INSERT ... ON CONFLICT DO NOTHING)
    await db.execute(
        text("""
            INSERT INTO video_playbooks (video_id, playbook_id)
            VALUES (:video_id, :playbook_id)
            ON CONFLICT DO NOTHING
        """),
        {"video_id": video_id, "playbook_id": request.playbook_id}
    )

    # Update Playbook's updated_at for sorting
    await db.execute(
        text("UPDATE playbooks SET updated_at = now() WHERE id = :playbook_id"),
        {"playbook_id": request.playbook_id}
    )

    await db.commit()

    # Get all Playbook IDs for this video
    playbook_ids_result = await db.execute(
        text("SELECT playbook_id FROM video_playbooks WHERE video_id = :video_id"),
        {"video_id": video_id}
    )
    playbook_ids = [row[0] for row in playbook_ids_result.fetchall()]

    logger.info(f"Assigned video {video_id} to playbook {request.playbook_id}")

    return VideoPlaybooksResponse(video_id=video_id, playbook_ids=playbook_ids)


@router.delete("/{video_id}/playbooks/{playbook_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_video_from_playbook(
    video_id: UUID,
    playbook_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Remove a video from a Playbook.

    Video remains in system, just unassigned from this Playbook.
    """
    # Verify video belongs to user
    video_result = await db.execute(
        select(Video).where(Video.id == video_id, Video.user_id == current_user.id)
    )
    if video_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    # Remove association
    await db.execute(
        text("""
            DELETE FROM video_playbooks
            WHERE video_id = :video_id AND playbook_id = :playbook_id
        """),
        {"video_id": video_id, "playbook_id": playbook_id}
    )
    await db.commit()

    logger.info(f"Removed video {video_id} from playbook {playbook_id}")


@router.get("/{video_id}/playbooks", response_model=VideoPlaybooksResponse)
async def get_video_playbooks(
    video_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VideoPlaybooksResponse:
    """Get all Playbooks a video belongs to."""
    # Verify video belongs to user
    video_result = await db.execute(
        select(Video).where(Video.id == video_id, Video.user_id == current_user.id)
    )
    if video_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    # Get Playbook IDs
    playbook_ids_result = await db.execute(
        text("SELECT playbook_id FROM video_playbooks WHERE video_id = :video_id"),
        {"video_id": video_id}
    )
    playbook_ids = [row[0] for row in playbook_ids_result.fetchall()]

    return VideoPlaybooksResponse(video_id=video_id, playbook_ids=playbook_ids)


@router.patch("/{video_id}/tags", response_model=VideoUpdateTagsResponse)
async def update_video_tags(
    video_id: UUID,
    request: VideoUpdateTagsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VideoUpdateTagsResponse:
    """Update tags for a video.

    Replaces all existing tags with the provided list.
    Tags are used for organization and appear in full-text search with highest weight.
    Maximum 20 tags per video.
    """
    # Verify video exists and belongs to user
    video_result = await db.execute(
        select(Video).where(Video.id == video_id, Video.user_id == current_user.id)
    )
    video = video_result.scalar_one_or_none()
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    # Normalize tags: strip whitespace, remove duplicates, filter empty
    normalized_tags = list(dict.fromkeys(
        tag.strip() for tag in request.tags if tag.strip()
    ))

    # Update video tags
    video.tags = normalized_tags
    await db.commit()
    await db.refresh(video)

    logger.info(f"Updated tags for video {video_id}: {normalized_tags}")

    return VideoUpdateTagsResponse(
        id=video.id,
        tags=video.tags or [],
    )


@router.get("/search", response_model=VideoSearchResponse)
async def search_videos(
    q: str = Query(..., min_length=1, max_length=200, description="Search query"),
    playbook_id: Optional[UUID] = Query(None, description="Limit search to specific Playbook"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
) -> VideoSearchResponse:
    """Full-text search across videos.

    Searches transcript, summary_bullets, and tags with weighted ranking:
    - Tags: weight A (highest priority)
    - Summary: weight B
    - Transcript: weight C (lowest priority)

    Results include highlighted matching text.
    """
    # Build search query with optional Playbook filter
    if playbook_id:
        search_query = text("""
            SELECT v.id, v.source_url, v.summary_bullets, v.tags, v.created_at,
                   ts_rank(v.search_vector, plainto_tsquery('english', :q)) AS rank,
                   ts_headline('english', coalesce(v.transcript, ''), plainto_tsquery('english', :q),
                       'MaxWords=30, MinWords=15, StartSel=<mark>, StopSel=</mark>') AS highlight
            FROM videos v
            JOIN video_playbooks vp ON vp.video_id = v.id
            WHERE v.user_id = :user_id
              AND v.search_vector @@ plainto_tsquery('english', :q)
              AND vp.playbook_id = :playbook_id
            ORDER BY rank DESC
            LIMIT :limit OFFSET :skip
        """)
        params = {
            "q": q,
            "user_id": current_user.id,
            "playbook_id": playbook_id,
            "limit": limit,
            "skip": skip,
        }
    else:
        search_query = text("""
            SELECT v.id, v.source_url, v.summary_bullets, v.tags, v.created_at,
                   ts_rank(v.search_vector, plainto_tsquery('english', :q)) AS rank,
                   ts_headline('english', coalesce(v.transcript, ''), plainto_tsquery('english', :q),
                       'MaxWords=30, MinWords=15, StartSel=<mark>, StopSel=</mark>') AS highlight
            FROM videos v
            WHERE v.user_id = :user_id
              AND v.search_vector @@ plainto_tsquery('english', :q)
            ORDER BY rank DESC
            LIMIT :limit OFFSET :skip
        """)
        params = {
            "q": q,
            "user_id": current_user.id,
            "limit": limit,
            "skip": skip,
        }

    result = await db.execute(search_query, params)
    rows = result.mappings().all()

    # Get total count
    count_query = text("""
        SELECT COUNT(*) FROM videos v
        WHERE v.user_id = :user_id
          AND v.search_vector @@ plainto_tsquery('english', :q)
    """)
    if playbook_id:
        count_query = text("""
            SELECT COUNT(*) FROM videos v
            JOIN video_playbooks vp ON vp.video_id = v.id
            WHERE v.user_id = :user_id
              AND v.search_vector @@ plainto_tsquery('english', :q)
              AND vp.playbook_id = :playbook_id
        """)
    count_result = await db.execute(count_query, {
        "q": q,
        "user_id": current_user.id,
        "playbook_id": playbook_id,
    } if playbook_id else {"q": q, "user_id": current_user.id})
    total = count_result.scalar_one()

    videos = [
        VideoSearchResult(
            id=row["id"],
            source_url=row["source_url"],
            summary_bullets=row["summary_bullets"],
            tags=row["tags"],
            created_at=row["created_at"],
            rank=row["rank"],
            highlight=row["highlight"],
        )
        for row in rows
    ]

    logger.info(f"Search '{q}' for user {current_user.id}: {total} results")

    return VideoSearchResponse(videos=videos, query=q, total=total)


@router.get("/{video_id}", response_model=VideoResponse)
async def get_video(
    video_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Video:
    """Get a video by ID.

    Only returns videos owned by the current user.
    """
    result = await db.execute(
        select(Video).where(
            Video.id == video_id,
            Video.user_id == current_user.id
        )
    )
    video = result.scalar_one_or_none()

    if video is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found"
        )

    return video


@router.get("", response_model=VideoListResponse)
async def list_videos(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    playbook_id: Optional[UUID] = Query(None, description="Filter by Playbook ID"),
    uncategorized: bool = Query(False, description="Show only videos not in any Playbook"),
    skip: int = Query(0, ge=0, description="Number of videos to skip"),
    limit: int = Query(20, ge=1, le=100, description="Maximum number of videos to return"),
) -> VideoListResponse:
    """List videos with optional Playbook filtering.

    - No filters: all user's videos
    - playbook_id: videos in specific Playbook
    - uncategorized=true: videos not in any Playbook
    """
    if uncategorized:
        # Videos with no Playbook associations
        count_query = text("""
            SELECT COUNT(*) FROM videos v
            WHERE v.user_id = :user_id
              AND NOT EXISTS (SELECT 1 FROM video_playbooks vp WHERE vp.video_id = v.id)
        """)
        videos_query = text("""
            SELECT v.* FROM videos v
            WHERE v.user_id = :user_id
              AND NOT EXISTS (SELECT 1 FROM video_playbooks vp WHERE vp.video_id = v.id)
            ORDER BY v.created_at DESC
            LIMIT :limit OFFSET :skip
        """)
        params = {"user_id": current_user.id, "limit": limit, "skip": skip}
    elif playbook_id:
        # Videos in specific Playbook
        count_query = text("""
            SELECT COUNT(*) FROM videos v
            JOIN video_playbooks vp ON vp.video_id = v.id
            WHERE v.user_id = :user_id AND vp.playbook_id = :playbook_id
        """)
        videos_query = text("""
            SELECT v.* FROM videos v
            JOIN video_playbooks vp ON vp.video_id = v.id
            WHERE v.user_id = :user_id AND vp.playbook_id = :playbook_id
            ORDER BY v.created_at DESC
            LIMIT :limit OFFSET :skip
        """)
        params = {"user_id": current_user.id, "playbook_id": playbook_id, "limit": limit, "skip": skip}
    else:
        # All videos (original behavior)
        count_result = await db.execute(
            select(func.count()).select_from(Video).where(Video.user_id == current_user.id)
        )
        total = count_result.scalar_one()

        result = await db.execute(
            select(Video)
            .where(Video.user_id == current_user.id)
            .order_by(Video.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        videos = result.scalars().all()

        return VideoListResponse(
            videos=[VideoResponse.model_validate(v) for v in videos],
            total=total
        )

    # Execute for filtered queries
    count_result = await db.execute(count_query, params)
    total = count_result.scalar_one()

    videos_result = await db.execute(videos_query, params)
    videos = videos_result.mappings().all()

    return VideoListResponse(
        videos=[VideoResponse(
            id=v["id"],
            source_url=v["source_url"],
            transcript=v["transcript"],
            summary_bullets=v["summary_bullets"],
            summary_steps=v["summary_steps"],
            summary_cards=v["summary_cards"],
            tags=v["tags"],
            created_at=v["created_at"],
            user_edited_summary=v["user_edited_summary"],
        ) for v in videos],
        total=total
    )


@router.delete("/{video_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_video(
    video_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete a video.

    Only allows deletion of videos owned by the current user.
    """
    result = await db.execute(
        select(Video).where(
            Video.id == video_id,
            Video.user_id == current_user.id
        )
    )
    video = result.scalar_one_or_none()

    if video is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found"
        )

    await db.delete(video)
    await db.commit()

    logger.info(f"Deleted video {video_id} for user {current_user.id}")


# ============================================================
# Bulk Operations
# ============================================================


@router.post("/bulk-delete", response_model=BulkDeleteResponse)
async def bulk_delete_videos(
    request: BulkDeleteRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BulkDeleteResponse:
    """Delete multiple videos at once.

    Only deletes videos owned by the current user.
    Returns count of actually deleted videos.
    Maximum 100 videos per request.

    Operation is atomic - either all succeed or all fail.

    Args:
        request: List of video IDs to delete (1-100)

    Returns:
        Count and IDs of actually deleted videos

    Raises:
        404: No matching videos found
    """
    # Use SQLAlchemy bulk delete for efficiency
    stmt = sa_delete(Video).where(
        Video.id.in_(request.video_ids),
        Video.user_id == current_user.id
    ).returning(Video.id)

    result = await db.execute(stmt, execution_options={"synchronize_session": False})
    deleted_ids = [row[0] for row in result.fetchall()]
    await db.commit()

    if not deleted_ids:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No matching videos found"
        )

    logger.info(f"Bulk deleted {len(deleted_ids)} videos for user {current_user.id}")

    return BulkDeleteResponse(
        deleted_count=len(deleted_ids),
        video_ids=deleted_ids,
    )


@router.post("/bulk-move", response_model=BulkMoveResponse)
async def bulk_move_to_playbook(
    request: BulkMoveRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BulkMoveResponse:
    """Move multiple videos to a Playbook.

    Adds videos to target Playbook (videos may already be in other Playbooks).
    Only moves videos owned by the current user.
    Maximum 100 videos per request.

    Operation handles duplicates gracefully - if video is already in
    the Playbook, it's silently skipped (ON CONFLICT DO NOTHING).

    Args:
        request: List of video IDs and target Playbook ID

    Returns:
        Count and IDs of moved videos, plus target Playbook ID

    Raises:
        404: Playbook not found or no matching videos found
    """
    # Verify Playbook exists and belongs to user
    playbook_result = await db.execute(
        select(Playbook).where(
            Playbook.id == request.playbook_id,
            Playbook.user_id == current_user.id
        )
    )
    playbook = playbook_result.scalar_one_or_none()
    if playbook is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playbook not found"
        )

    # Verify videos belong to user
    videos_result = await db.execute(
        select(Video.id).where(
            Video.id.in_(request.video_ids),
            Video.user_id == current_user.id
        )
    )
    valid_video_ids = [row[0] for row in videos_result.fetchall()]

    if not valid_video_ids:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No matching videos found"
        )

    # Bulk insert associations (ON CONFLICT DO NOTHING for existing)
    for video_id in valid_video_ids:
        await db.execute(
            text("""
                INSERT INTO video_playbooks (video_id, playbook_id)
                VALUES (:video_id, :playbook_id)
                ON CONFLICT DO NOTHING
            """),
            {"video_id": video_id, "playbook_id": request.playbook_id}
        )

    # Update Playbook's updated_at for sorting
    await db.execute(
        text("UPDATE playbooks SET updated_at = now() WHERE id = :playbook_id"),
        {"playbook_id": request.playbook_id}
    )

    await db.commit()

    logger.info(f"Bulk moved {len(valid_video_ids)} videos to playbook {request.playbook_id}")

    return BulkMoveResponse(
        moved_count=len(valid_video_ids),
        playbook_id=request.playbook_id,
        video_ids=valid_video_ids,
    )


@router.post("/bulk-add-to-favorites", response_model=BulkMoveResponse)
async def bulk_add_to_favorites(
    request: BulkAddToFavoritesRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BulkMoveResponse:
    """Add multiple videos to Favorites Playbook.

    Convenience endpoint that finds user's Favorites Playbook automatically.
    Creates Favorites Playbook if somehow missing (shouldn't happen normally).

    Args:
        request: List of video IDs to add to Favorites (1-100)

    Returns:
        Count and IDs of moved videos, plus Favorites Playbook ID

    Raises:
        404: No matching videos found
    """
    # Find user's Favorites Playbook
    favorites_result = await db.execute(
        select(Playbook).where(
            Playbook.user_id == current_user.id,
            Playbook.is_system == True,
            Playbook.name == "Favorites"
        )
    )
    favorites = favorites_result.scalar_one_or_none()

    if favorites is None:
        # Create Favorites if somehow missing
        favorites = Playbook(
            user_id=current_user.id,
            name="Favorites",
            icon="star.fill",
            is_system=True,
        )
        db.add(favorites)
        await db.commit()
        await db.refresh(favorites)
        logger.info(f"Created missing Favorites playbook for user {current_user.id}")

    # Verify videos belong to user
    videos_result = await db.execute(
        select(Video.id).where(
            Video.id.in_(request.video_ids),
            Video.user_id == current_user.id
        )
    )
    valid_video_ids = [row[0] for row in videos_result.fetchall()]

    if not valid_video_ids:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No matching videos found"
        )

    # Bulk insert to Favorites
    for video_id in valid_video_ids:
        await db.execute(
            text("""
                INSERT INTO video_playbooks (video_id, playbook_id)
                VALUES (:video_id, :playbook_id)
                ON CONFLICT DO NOTHING
            """),
            {"video_id": video_id, "playbook_id": favorites.id}
        )

    await db.execute(
        text("UPDATE playbooks SET updated_at = now() WHERE id = :playbook_id"),
        {"playbook_id": favorites.id}
    )

    await db.commit()

    logger.info(f"Bulk added {len(valid_video_ids)} videos to Favorites")

    return BulkMoveResponse(
        moved_count=len(valid_video_ids),
        playbook_id=favorites.id,
        video_ids=valid_video_ids,
    )
