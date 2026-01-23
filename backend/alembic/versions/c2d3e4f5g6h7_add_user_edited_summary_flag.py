"""Add user_edited_summary flag to Video

Revision ID: c2d3e4f5g6h7
Revises: fb9ffa569e14
Create Date: 2026-01-23

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'c2d3e4f5g6h7'
down_revision: Union[str, None] = 'fb9ffa569e14'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add user_edited_summary boolean flag to videos table
    # Default is False - user hasn't manually edited the AI-generated summary
    op.add_column('videos', sa.Column('user_edited_summary', sa.Boolean(), nullable=False, server_default='false'))


def downgrade() -> None:
    # Remove user_edited_summary flag from videos table
    op.drop_column('videos', 'user_edited_summary')
