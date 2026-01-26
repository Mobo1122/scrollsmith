"""HabitCompletion model for tracking habit completions."""

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, String, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.habit import Habit


class HabitCompletion(Base):
    """Record of a single habit completion."""

    __tablename__ = "habit_completions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    habit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("habits.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    completed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    user_timezone: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="UTC",
        comment="IANA timezone identifier for accurate streak calculation",
    )

    # Relationship
    habit: Mapped["Habit"] = relationship(
        "Habit",
        back_populates="completions",
    )

    def __repr__(self) -> str:
        return f"<HabitCompletion {self.habit_id} at {self.completed_at}>"
