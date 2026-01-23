"""Video model."""

import uuid
from datetime import datetime
from typing import List, Optional, TYPE_CHECKING

from sqlalchemy import String, Text, DateTime, func, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.playbook import Playbook
    from app.models.habit import Habit


class Video(Base):
    """Video content with transcript and summary."""

    __tablename__ = "videos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    playbook_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("playbooks.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    source_url: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )
    transcript: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    summary_bullets: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    summary_steps: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    summary_cards: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    user_edited_summary: Mapped[bool] = mapped_column(
        default=False,
        nullable=False,
    )
    tags: Mapped[Optional[List[str]]] = mapped_column(
        ARRAY(String),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="videos",
    )
    playbook: Mapped[Optional["Playbook"]] = relationship(
        "Playbook",
        back_populates="videos",
    )
    habits: Mapped[List["Habit"]] = relationship(
        "Habit",
        back_populates="video",
    )

    def __repr__(self) -> str:
        return f"<Video {self.id}>"
