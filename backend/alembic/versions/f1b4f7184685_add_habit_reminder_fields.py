"""Add habit reminder fields

Revision ID: f1b4f7184685
Revises: d3e4f5g6h7i8
Create Date: 2026-01-26

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY, INTEGER


# revision identifiers, used by Alembic.
revision: str = 'f1b4f7184685'
down_revision: Union[str, None] = 'd3e4f5g6h7i8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add reminder configuration fields to habits table."""
    # reminder_time: Time of day for reminder (user's local time)
    op.add_column(
        'habits',
        sa.Column(
            'reminder_time',
            sa.Time(),
            nullable=True,
            comment="Time of day for reminder (user's local time)"
        )
    )

    # reminder_days: Days of week for reminder (1=Sun through 7=Sat)
    # Null for daily habits (means "every day")
    op.add_column(
        'habits',
        sa.Column(
            'reminder_days',
            ARRAY(INTEGER),
            nullable=True,
            comment="Days of week for reminder (1=Sun through 7=Sat). Null for daily."
        )
    )

    # is_active: Whether habit is active (false = paused, no reminders)
    # server_default='true' ensures existing habits are active
    op.add_column(
        'habits',
        sa.Column(
            'is_active',
            sa.Boolean(),
            nullable=False,
            server_default='true',
            comment="Whether habit is active (false = paused, no reminders)"
        )
    )


def downgrade() -> None:
    """Remove reminder configuration fields from habits table."""
    op.drop_column('habits', 'is_active')
    op.drop_column('habits', 'reminder_days')
    op.drop_column('habits', 'reminder_time')
