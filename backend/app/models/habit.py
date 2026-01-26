"""Habit model."""

import uuid
from datetime import datetime, time
from typing import Optional, List, TYPE_CHECKING

from sqlalchemy import String, Integer, DateTime, Time, Boolean, func, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, ARRAY, INTEGER
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.video import Video
    from app.models.habit_completion import HabitCompletion


class Habit(Base):
    """Habit extracted from video content."""

    __tablename__ = "habits"

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
    video_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("videos.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )
    frequency: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )
    current_streak: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    longest_streak: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    reminder_time: Mapped[Optional[time]] = mapped_column(
        Time,
        nullable=True,
        comment="Time of day for reminder (user's local time)",
    )
    reminder_days: Mapped[Optional[List[int]]] = mapped_column(
        ARRAY(INTEGER),
        nullable=True,
        comment="Days of week for reminder (1=Sun through 7=Sat). Null for daily.",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        comment="Whether habit is active (false = paused, no reminders)",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="habits",
    )
    video: Mapped[Optional["Video"]] = relationship(
        "Video",
        back_populates="habits",
    )
    completions: Mapped[List["HabitCompletion"]] = relationship(
        "HabitCompletion",
        back_populates="habit",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Habit {self.title}>"
