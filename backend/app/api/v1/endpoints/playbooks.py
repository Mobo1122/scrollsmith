"""Playbook CRUD endpoints."""

import logging
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, get_db
from app.models import User, Playbook, Video, video_playbooks
from app.schemas.playbook import (
    PlaybookCreate,
    PlaybookUpdate,
    PlaybookResponse,
    PlaybookListResponse,
    PlaybookDeleteResponse,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/playbooks", tags=["playbooks"])

MAX_FREE_PLAYBOOKS = 3


@router.post("", response_model=PlaybookResponse, status_code=status.HTTP_201_CREATED)
async def create_playbook(
    request: PlaybookCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PlaybookResponse:
    """Create a new Playbook.

    Free users limited to 3 Playbooks. Pro users unlimited.
    """
    # Check free tier limit (exclude system playbooks from count)
    if current_user.subscription_tier == "free":
        count_result = await db.execute(
            select(func.count()).select_from(Playbook).where(
                Playbook.user_id == current_user.id,
                Playbook.is_system == False
            )
        )
        count = count_result.scalar_one()
        if count >= MAX_FREE_PLAYBOOKS:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "playbook_limit_reached",
                    "message": f"Free tier limited to {MAX_FREE_PLAYBOOKS} Playbooks",
                    "current": count,
                    "limit": MAX_FREE_PLAYBOOKS,
                    "upgrade_url": "/subscribe/pro"
                }
            )

    playbook = Playbook(
        user_id=current_user.id,
        name=request.name,
        icon=request.icon,
        is_system=False,
    )
    db.add(playbook)
    await db.commit()
    await db.refresh(playbook)

    logger.info(f"Created playbook '{playbook.name}' ({playbook.id}) for user {current_user.id}")

    return PlaybookResponse(
        id=playbook.id,
        name=playbook.name,
        icon=playbook.icon,
        is_system=playbook.is_system,
        video_count=0,
        created_at=playbook.created_at,
        updated_at=playbook.updated_at,
    )


@router.get("", response_model=PlaybookListResponse)
async def list_playbooks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PlaybookListResponse:
    """List all Playbooks for current user.

    Sorted by updated_at descending (most recently active first).
    System Playbooks (Favorites) appear first.
    """
    # Get playbooks with video counts
    result = await db.execute(
        select(Playbook)
        .where(Playbook.user_id == current_user.id)
        .options(selectinload(Playbook.videos))
        .order_by(Playbook.is_system.desc(), Playbook.updated_at.desc())
    )
    playbooks = result.scalars().all()

    responses = [
        PlaybookResponse(
            id=p.id,
            name=p.name,
            icon=p.icon,
            is_system=p.is_system,
            video_count=len(p.videos),
            created_at=p.created_at,
            updated_at=p.updated_at,
        )
        for p in playbooks
    ]

    return PlaybookListResponse(playbooks=responses, total=len(responses))


@router.get("/{playbook_id}", response_model=PlaybookResponse)
async def get_playbook(
    playbook_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PlaybookResponse:
    """Get a single Playbook by ID."""
    result = await db.execute(
        select(Playbook)
        .where(Playbook.id == playbook_id, Playbook.user_id == current_user.id)
        .options(selectinload(Playbook.videos))
    )
    playbook = result.scalar_one_or_none()

    if playbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Playbook not found")

    return PlaybookResponse(
        id=playbook.id,
        name=playbook.name,
        icon=playbook.icon,
        is_system=playbook.is_system,
        video_count=len(playbook.videos),
        created_at=playbook.created_at,
        updated_at=playbook.updated_at,
    )


@router.patch("/{playbook_id}", response_model=PlaybookResponse)
async def update_playbook(
    playbook_id: UUID,
    request: PlaybookUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PlaybookResponse:
    """Update Playbook name or icon."""
    result = await db.execute(
        select(Playbook)
        .where(Playbook.id == playbook_id, Playbook.user_id == current_user.id)
        .options(selectinload(Playbook.videos))
    )
    playbook = result.scalar_one_or_none()

    if playbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Playbook not found")

    if request.name is not None:
        playbook.name = request.name
    if request.icon is not None:
        playbook.icon = request.icon

    await db.commit()
    await db.refresh(playbook)

    logger.info(f"Updated playbook {playbook_id} for user {current_user.id}")

    return PlaybookResponse(
        id=playbook.id,
        name=playbook.name,
        icon=playbook.icon,
        is_system=playbook.is_system,
        video_count=len(playbook.videos),
        created_at=playbook.created_at,
        updated_at=playbook.updated_at,
    )


@router.delete("/{playbook_id}", response_model=PlaybookDeleteResponse)
async def delete_playbook(
    playbook_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PlaybookDeleteResponse:
    """Delete a Playbook.

    Videos are NOT deleted - they become uncategorized (removed from this Playbook's association).
    System Playbooks (Favorites) cannot be deleted.
    """
    result = await db.execute(
        select(Playbook)
        .where(Playbook.id == playbook_id, Playbook.user_id == current_user.id)
        .options(selectinload(Playbook.videos))
    )
    playbook = result.scalar_one_or_none()

    if playbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Playbook not found")

    if playbook.is_system:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot delete system Playbook (Favorites)"
        )

    video_count = len(playbook.videos)

    # Delete Playbook - cascade deletes associations but not videos
    await db.delete(playbook)
    await db.commit()

    logger.info(f"Deleted playbook {playbook_id} for user {current_user.id}, {video_count} videos now uncategorized")

    return PlaybookDeleteResponse(
        deleted_id=playbook_id,
        videos_moved_to_uncategorized=video_count,
    )
