"""Habit extraction and management endpoints.

Pro tier only: Habit extraction requires Pro subscription.
"""

import logging
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models import User, Video, Habit
from app.schemas.habit import (
    HabitSuggestion,
    HabitExtractionResponse,
    HabitCreateRequest,
    HabitResponse,
)
from app.services.habit_extraction import (
    habit_extraction_service,
    HabitExtractionError,
    NoAPIKeyError,
    ExtractionFailedError,
    TranscriptTooShortError,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/habits", tags=["habits"])


@router.post("/videos/{video_id}/extract", response_model=HabitExtractionResponse)
async def extract_habits(
    video_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> HabitExtractionResponse:
    """Extract habit suggestions from a video transcript (Pro only).

    Returns 1-3 habit suggestions that user can select from.
    Does NOT create habits - use POST /habits to create selected habits.

    Raises:
        403: Pro subscription required
        404: Video not found
        400: Video has no transcript
        503: Claude API not configured
        500: Extraction failed
    """
    # Pro tier gate - server-side for security
    if current_user.subscription_tier != "pro":
        logger.info(f"Free user {current_user.id} attempted habit extraction")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "pro_required",
                "message": "Habit extraction requires Pro subscription",
                "upgrade_url": "/subscribe/pro"
            }
        )

    # Check service availability
    if not habit_extraction_service.is_available:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Habit extraction service not configured. Contact support."
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

    try:
        suggestions = await habit_extraction_service.extract_habits(video.transcript)
        logger.info(f"Extracted {len(suggestions)} habits for video {video_id}")

        return HabitExtractionResponse(
            video_id=video.id,
            suggestions=suggestions
        )

    except TranscriptTooShortError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

    except NoAPIKeyError:
        logger.error("Claude API not configured for habit extraction")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Habit extraction service not configured"
        )

    except ExtractionFailedError as e:
        logger.error(f"Habit extraction failed for video {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Habit extraction failed: {str(e)}"
        )

    except HabitExtractionError as e:
        logger.error(f"Habit extraction error for video {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("", response_model=HabitResponse, status_code=status.HTTP_201_CREATED)
async def create_habit(
    request: HabitCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Habit:
    """Create a habit from a selected suggestion.

    Call this after user selects habits from extract response.
    Habits are linked to source video for reference.

    Raises:
        403: Pro subscription required
        404: Video not found
    """
    # Pro tier gate
    if current_user.subscription_tier != "pro":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "pro_required",
                "message": "Habit creation requires Pro subscription",
                "upgrade_url": "/subscribe/pro"
            }
        )

    # Verify video exists and belongs to user
    result = await db.execute(
        select(Video).where(
            Video.id == request.video_id,
            Video.user_id == current_user.id
        )
    )
    video = result.scalar_one_or_none()

    if video is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found"
        )

    # Create habit
    habit = Habit(
        user_id=current_user.id,
        video_id=request.video_id,
        title=request.title,
        frequency=request.frequency,
    )
    db.add(habit)
    await db.commit()
    await db.refresh(habit)

    logger.info(f"Created habit '{habit.title}' for user {current_user.id} from video {video.id}")

    return habit


@router.get("", response_model=List[HabitResponse])
async def list_habits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[Habit]:
    """List all habits for the current user.

    Returns habits sorted by created_at descending (newest first).
    """
    result = await db.execute(
        select(Habit)
        .where(Habit.user_id == current_user.id)
        .order_by(Habit.created_at.desc())
    )
    return list(result.scalars().all())


@router.delete("/{habit_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_habit(
    habit_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete a habit.

    Only allows deletion of habits owned by the current user.
    """
    result = await db.execute(
        select(Habit).where(
            Habit.id == habit_id,
            Habit.user_id == current_user.id
        )
    )
    habit = result.scalar_one_or_none()

    if habit is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Habit not found"
        )

    await db.delete(habit)
    await db.commit()

    logger.info(f"Deleted habit {habit_id} for user {current_user.id}")
