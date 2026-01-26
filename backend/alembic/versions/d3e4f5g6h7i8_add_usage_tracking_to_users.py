"""Add usage tracking fields to users

Revision ID: d3e4f5g6h7i8
Revises: 167d2182ec20
Create Date: 2026-01-25

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd3e4f5g6h7i8'
down_revision: Union[str, None] = '167d2182ec20'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add usage tracking fields for free tier video limits."""
    # videos_this_month: count of videos processed in current billing period
    op.add_column(
        'users',
        sa.Column('videos_this_month', sa.Integer(), nullable=False, server_default='0')
    )

    # usage_reset_date: when to reset the monthly counter (1st of next month)
    # Nullable initially - set on first video or sync
    op.add_column(
        'users',
        sa.Column(
            'usage_reset_date',
            sa.DateTime(timezone=True),
            nullable=True
        )
    )


def downgrade() -> None:
    """Remove usage tracking fields."""
    op.drop_column('users', 'usage_reset_date')
    op.drop_column('users', 'videos_this_month')
