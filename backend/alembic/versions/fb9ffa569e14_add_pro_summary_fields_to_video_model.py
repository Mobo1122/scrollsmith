"""Add Pro summary fields to Video model

Revision ID: fb9ffa569e14
Revises: a1b2c3d4e5f6
Create Date: 2026-01-23

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'fb9ffa569e14'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add Pro summary format columns to videos table
    op.add_column('videos', sa.Column('summary_steps', sa.Text(), nullable=True))
    op.add_column('videos', sa.Column('summary_cards', sa.Text(), nullable=True))


def downgrade() -> None:
    # Remove Pro summary format columns from videos table
    op.drop_column('videos', 'summary_cards')
    op.drop_column('videos', 'summary_steps')
