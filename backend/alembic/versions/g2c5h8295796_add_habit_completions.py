"""Add habit_completions table

Revision ID: g2c5h8295796
Revises: f1b4f7184685
Create Date: 2026-01-26

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'g2c5h8295796'
down_revision: Union[str, None] = 'f1b4f7184685'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create habit_completions table for tracking habit completions."""
    op.create_table(
        'habit_completions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            'habit_id',
            postgresql.UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column(
            'completed_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.Column(
            'user_timezone',
            sa.String(length=50),
            nullable=False,
            server_default='UTC',
            comment='IANA timezone identifier for accurate streak calculation',
        ),
        sa.ForeignKeyConstraint(
            ['habit_id'],
            ['habits.id'],
            ondelete='CASCADE',
        ),
    )
    op.create_index(
        'ix_habit_completions_habit_id',
        'habit_completions',
        ['habit_id'],
    )


def downgrade() -> None:
    """Drop habit_completions table."""
    op.drop_index('ix_habit_completions_habit_id', table_name='habit_completions')
    op.drop_table('habit_completions')
