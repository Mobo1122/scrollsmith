"""Habit extraction and management endpoints.

Pro tier only: Habit extraction requires Pro subscription.
"""

import logging
from datetime import datetime, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models import User, Video, Habit, HabitCompletion
from app.schemas.habit import (
    HabitSuggestion,
    HabitExtractionResponse,
    HabitCreateRequest,
    HabitUpdateRequest,
    HabitResponse,
    HabitCompletionCreate,
    HabitCompletionResponse,
)
from app.services.habit_extraction import (
    habit_extraction_service,
    HabitExtractionError,
    NoAPIKeyError,
    ExtractionFailedError,
    TranscriptTooShortError,
)
from app.services.streak_calculator import calculate_streaks_with_forgiveness

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


@router.patch("/{habit_id}", response_model=HabitResponse)
async def update_habit(
    habit_id: UUID,
    request: HabitUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Habit:
    """Update a habit's details (partial update).

    Only provided fields are updated.
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

    # Apply updates
    update_data = request.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(habit, field, value)

    await db.commit()
    await db.refresh(habit)

    logger.info(f"Updated habit {habit_id} for user {current_user.id}")
    return habit


@router.post("/{habit_id}/complete", response_model=HabitCompletionResponse)
async def complete_habit(
    habit_id: UUID,
    request: HabitCompletionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> HabitCompletionResponse:
    """Record a habit completion.

    Stores completion with user's timezone for accurate streak calculation.
    Updates current_streak and longest_streak on the habit.
    """
    # Verify habit belongs to user
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

    # Create completion record
    completion = HabitCompletion(
        habit_id=habit_id,
        completed_at=datetime.now(timezone.utc),
        user_timezone=request.user_timezone,
    )
    db.add(completion)

    # Flush to ensure completion is in DB before streak calculation
    await db.flush()

    # Recalculate streaks
    current_streak, longest_streak = await calculate_streaks_with_forgiveness(
        db, habit_id, request.user_timezone
    )
    habit.current_streak = current_streak
    habit.longest_streak = max(habit.longest_streak, longest_streak)

    await db.commit()
    await db.refresh(completion)

    logger.info(f"Completed habit {habit_id}, streak: {current_streak}")

    return HabitCompletionResponse(
        id=completion.id,
        habit_id=habit_id,
        completed_at=completion.completed_at,
        current_streak=habit.current_streak,
        longest_streak=habit.longest_streak,
    )


@router.get("/{habit_id}/completions", response_model=List[HabitCompletionResponse])
async def get_habit_completions(
    habit_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[HabitCompletionResponse]:
    """Get all completions for a habit (for calendar display).

    Returns completions ordered by date descending (most recent first).
    """
    # Verify habit belongs to user
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

    # Fetch completions
    result = await db.execute(
        select(HabitCompletion)
        .where(HabitCompletion.habit_id == habit_id)
        .order_by(HabitCompletion.completed_at.desc())
    )
    completions = result.scalars().all()

    return [
        HabitCompletionResponse(
            id=c.id,
            habit_id=c.habit_id,
            completed_at=c.completed_at,
            current_streak=habit.current_streak,
            longest_streak=habit.longest_streak,
        )
        for c in completions
    ]
