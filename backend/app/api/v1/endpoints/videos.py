"""Video processing endpoints.

v1: Server-side transcription for camera roll uploads, YouTube caption fetching.
TikTok/Instagram URL support deferred to v2 (requires WhisperKit on iOS).
"""

import logging
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models import User, Video
from app.schemas.video import (
    YouTubeCaptionsRequest,
    YouTubeCaptionsResponse,
    VideoCreateRequest,
    VideoResponse,
    VideoListResponse,
    SummarizeRequest,
    SummarizeResponse,
    TranscriptQuality,
)
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
    """
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
    """
    try:
        caption_text, metadata = await youtube_captions_service.get_captions(request.url)

        # Create Video record with transcript
        video = Video(
            user_id=current_user.id,
            source_url=request.url,
            transcript=caption_text,
        )
        db.add(video)
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
    """
    video = Video(
        user_id=current_user.id,
        source_url=request.source_url,
        transcript=request.transcript,
    )
    db.add(video)
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
    if not request.regenerate:
        cached_data = None
        tags = None

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
    skip: int = Query(0, ge=0, description="Number of videos to skip"),
    limit: int = Query(20, ge=1, le=100, description="Maximum number of videos to return"),
) -> VideoListResponse:
    """List all videos for the current user.

    Returns videos sorted by creation date (newest first).
    """
    # Get total count
    count_result = await db.execute(
        select(func.count()).select_from(Video).where(Video.user_id == current_user.id)
    )
    total = count_result.scalar_one()

    # Get videos
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
