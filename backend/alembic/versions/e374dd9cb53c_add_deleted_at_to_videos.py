"""add_deleted_at_to_videos

Revision ID: e374dd9cb53c
Revises: h3d6i9406907
Create Date: 2026-02-03 12:01:07.608854

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e374dd9cb53c'
down_revision: Union[str, Sequence[str], None] = 'h3d6i9406907'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add deleted_at column to videos table for soft delete functionality."""
    # Add deleted_at column (nullable timestamp)
    op.add_column('videos', sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True))

    # Add index for performance when filtering deleted videos
    op.create_index(
        'ix_videos_deleted_at',
        'videos',
        ['deleted_at'],
        unique=False,
        postgresql_where=sa.text('deleted_at IS NOT NULL')
    )


def downgrade() -> None:
    """Remove deleted_at column and index."""
    # Drop index first
    op.drop_index('ix_videos_deleted_at', table_name='videos')

    # Drop column
    op.drop_column('videos', 'deleted_at')
