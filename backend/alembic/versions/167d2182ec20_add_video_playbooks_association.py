"""add_video_playbooks_association

Revision ID: 167d2182ec20
Revises: c2d3e4f5g6h7
Create Date: 2026-01-23 21:48:20.049722

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '167d2182ec20'
down_revision: Union[str, Sequence[str], None] = 'c2d3e4f5g6h7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: one-to-many -> many-to-many + full-text search."""
    # 1. Create video_playbooks association table
    op.create_table(
        'video_playbooks',
        sa.Column(
            'video_id',
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey('videos.id', ondelete='CASCADE'),
            primary_key=True,
        ),
        sa.Column(
            'playbook_id',
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey('playbooks.id', ondelete='CASCADE'),
            primary_key=True,
        ),
        sa.Column(
            'added_at',
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )

    # 2. Add is_system and updated_at to playbooks
    op.add_column(
        'playbooks',
        sa.Column('is_system', sa.Boolean(), nullable=False, server_default='false'),
    )
    op.add_column(
        'playbooks',
        sa.Column(
            'updated_at',
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # 3. Migrate existing one-to-many data to association table
    op.execute("""
        INSERT INTO video_playbooks (video_id, playbook_id, added_at)
        SELECT id, playbook_id, created_at
        FROM videos
        WHERE playbook_id IS NOT NULL
    """)

    # 4. Drop old playbook_id foreign key from videos
    op.drop_constraint('videos_playbook_id_fkey', 'videos', type_='foreignkey')
    op.drop_index('ix_videos_playbook_id', 'videos')
    op.drop_column('videos', 'playbook_id')

    # 5. Add search_vector generated column with weighted fields
    # A=tags (most relevant), B=summary bullets, C=transcript (least relevant)
    op.execute("""
        ALTER TABLE videos
        ADD COLUMN search_vector tsvector
        GENERATED ALWAYS AS (
            setweight(to_tsvector('english', coalesce(array_to_string(tags, ' '), '')), 'A') ||
            setweight(to_tsvector('english', coalesce(summary_bullets, '')), 'B') ||
            setweight(to_tsvector('english', coalesce(transcript, '')), 'C')
        ) STORED
    """)

    # 6. Create GIN index for fast full-text search
    op.execute("CREATE INDEX idx_videos_search ON videos USING GIN (search_vector)")


def downgrade() -> None:
    """Downgrade schema: many-to-many -> one-to-many, remove full-text search."""
    # 1. Drop search index and column
    op.execute("DROP INDEX idx_videos_search")
    op.execute("ALTER TABLE videos DROP COLUMN search_vector")

    # 2. Re-add playbook_id column to videos
    op.add_column(
        'videos',
        sa.Column(
            'playbook_id',
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.create_index('ix_videos_playbook_id', 'videos', ['playbook_id'])
    op.create_foreign_key(
        'videos_playbook_id_fkey',
        'videos',
        'playbooks',
        ['playbook_id'],
        ['id'],
        ondelete='SET NULL',
    )

    # 3. Migrate data back (lossy - videos in multiple playbooks keep only one)
    op.execute("""
        UPDATE videos v
        SET playbook_id = (
            SELECT playbook_id FROM video_playbooks vp WHERE vp.video_id = v.id LIMIT 1
        )
    """)

    # 4. Drop playbook columns
    op.drop_column('playbooks', 'updated_at')
    op.drop_column('playbooks', 'is_system')

    # 5. Drop association table
    op.drop_table('video_playbooks')
