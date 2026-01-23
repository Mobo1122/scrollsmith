"""Playbook request/response schemas."""

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict


class PlaybookCreate(BaseModel):
    """Request to create a Playbook."""
    name: str = Field(..., min_length=1, max_length=100)
    icon: Optional[str] = Field(None, max_length=50)


class PlaybookUpdate(BaseModel):
    """Request to update a Playbook."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    icon: Optional[str] = Field(None, max_length=50)


class PlaybookResponse(BaseModel):
    """Playbook response with video count."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    icon: Optional[str]
    is_system: bool
    video_count: int = 0  # Computed from relationship
    created_at: datetime
    updated_at: datetime


class PlaybookListResponse(BaseModel):
    """List of Playbooks."""
    playbooks: List[PlaybookResponse]
    total: int


class PlaybookDeleteResponse(BaseModel):
    """Response after Playbook deletion."""
    deleted_id: UUID
    videos_moved_to_uncategorized: int
