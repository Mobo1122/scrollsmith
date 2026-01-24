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

    # 5. Add search_vector column (updated via trigger, not generated column)
    # PostgreSQL requires IMMUTABLE functions for generated columns, but to_tsvector is STABLE
    op.add_column(
        'videos',
        sa.Column('search_vector', postgresql.TSVECTOR(), nullable=True),
    )

    # 6. Create function to update search_vector
    op.execute("""
        CREATE OR REPLACE FUNCTION videos_search_vector_update() RETURNS trigger AS $$
        BEGIN
            NEW.search_vector :=
                setweight(to_tsvector('english', coalesce(array_to_string(NEW.tags, ' '), '')), 'A') ||
                setweight(to_tsvector('english', coalesce(NEW.summary_bullets, '')), 'B') ||
                setweight(to_tsvector('english', coalesce(NEW.transcript, '')), 'C');
            RETURN NEW;
        END
        $$ LANGUAGE plpgsql;
    """)

    # 7. Create trigger to auto-update search_vector on INSERT/UPDATE
    op.execute("""
        CREATE TRIGGER videos_search_vector_trigger
        BEFORE INSERT OR UPDATE ON videos
        FOR EACH ROW EXECUTE FUNCTION videos_search_vector_update();
    """)

    # 8. Populate search_vector for existing rows
    op.execute("""
        UPDATE videos SET
            search_vector =
                setweight(to_tsvector('english', coalesce(array_to_string(tags, ' '), '')), 'A') ||
                setweight(to_tsvector('english', coalesce(summary_bullets, '')), 'B') ||
                setweight(to_tsvector('english', coalesce(transcript, '')), 'C');
    """)

    # 9. Create GIN index for fast full-text search
    op.execute("CREATE INDEX idx_videos_search ON videos USING GIN (search_vector)")


def downgrade() -> None:
    """Downgrade schema: many-to-many -> one-to-many, remove full-text search."""
    # 1. Drop search index, trigger, function, and column
    op.execute("DROP INDEX idx_videos_search")
    op.execute("DROP TRIGGER videos_search_vector_trigger ON videos")
    op.execute("DROP FUNCTION videos_search_vector_update()")
    op.drop_column('videos', 'search_vector')

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
