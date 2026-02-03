# Backend Changes for Phase 15 (Waves 4 & 5)

## Summary

Implemented soft delete with 30-day retention for the "Recently Deleted" feature and added tags aggregation endpoint.

## Database Changes

### Migration: `e374dd9cb53c_add_deleted_at_to_videos.py`

Adds `deleted_at` column to `videos` table with partial index for performance.

```sql
-- Add column
ALTER TABLE videos ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE NULL;

-- Add partial index (only indexes rows where deleted_at IS NOT NULL)
CREATE INDEX ix_videos_deleted_at ON videos (deleted_at)
WHERE deleted_at IS NOT NULL;
```

**To apply migration:**
```bash
cd backend
python3 -m alembic upgrade head
```

## API Changes

### Wave 4: Soft Delete with Recently Deleted

#### Modified Endpoints

**1. DELETE /api/v1/videos/{id}** (Soft Delete)
- **Before**: Hard delete (permanently removed from database)
- **After**: Soft delete (sets `deleted_at = NOW()`)
- Videos stay in "Recently Deleted" for 30 days before permanent deletion
- Response: 204 No Content

**2. GET /api/v1/videos** (List Videos)
- **New query parameters**:
  - `deleted=true` - Show only soft-deleted videos from last 30 days
  - `tag={tag_name}` - Filter by tag name
- **Default behavior**: Excludes soft-deleted videos (`WHERE deleted_at IS NULL`)
- All existing filters (playbook_id, uncategorized) now exclude soft-deleted videos

**3. All other video endpoints** now exclude soft-deleted videos:
- GET /api/v1/videos/{id}
- POST /api/v1/videos/{id}/summarize
- PATCH /api/v1/videos/{id}/summary
- POST /api/v1/videos/{id}/playbooks
- DELETE /api/v1/videos/{id}/playbooks/{playbook_id}
- GET /api/v1/videos/{id}/playbooks
- PATCH /api/v1/videos/{id}/tags
- GET /api/v1/videos/search
- POST /api/v1/videos/bulk-delete
- POST /api/v1/videos/bulk-move
- POST /api/v1/videos/bulk-add-to-favorites

#### New Endpoints

**1. PATCH /api/v1/videos/{id}/restore**
- Restores a soft-deleted video (clears `deleted_at`)
- Only works on videos deleted within last 30 days
- Returns: 200 OK with restored VideoResponse
- Errors:
  - 404: Video not found
  - 410 Gone: Video was deleted more than 30 days ago

**2. DELETE /api/v1/videos/{id}/permanent**
- Permanently deletes a video immediately (bypasses 30-day retention)
- Irreversible operation
- Works on both active and soft-deleted videos
- Response: 204 No Content

### Wave 5: Tags Aggregation

#### New Endpoints

**1. GET /api/v1/videos/tags**
- Returns all unique tags with video counts
- Sorted by video count DESC (most used first)
- Only includes tags from active (non-deleted) videos
- Response format:
```json
[
  {
    "id": "productivity",
    "name": "productivity",
    "videoCount": 15,
    "createdAt": "2024-01-01T00:00:00Z"
  },
  ...
]
```

## Schema Changes

### VideoResponse

Added `deleted_at` field:
```python
class VideoResponse(BaseModel):
    # ... existing fields
    deleted_at: Optional[datetime] = None
```

## Behavioral Changes

### Soft Delete Cascade

When a video is soft-deleted:
1. Video is **not** removed from playbooks
2. Video is **not** removed from search index
3. Video simply gets `deleted_at` timestamp
4. All queries exclude soft-deleted videos by default

When a video is permanently deleted (after 30 days or manual):
1. Database CASCADE rules apply
2. Associated habits are deleted
3. Playbook associations are removed
4. Search vector is removed

### Query Scoping

**All video queries now include:**
```python
Video.deleted_at == None  # Exclude soft-deleted videos
```

**Exception:** When `deleted=true` query parameter is used:
```python
Video.deleted_at != None AND
Video.deleted_at > NOW() - INTERVAL '30 days'
```

## Cron Job Requirement

### 30-Day Auto-Deletion Job

**Purpose**: Permanently delete videos that have been in "Recently Deleted" for 30+ days.

**Implementation Options:**

#### Option 1: Railway Cron Job (Recommended)

Add to `railway.json`:
```json
{
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "gunicorn app.main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  },
  "cron": [
    {
      "schedule": "0 0 * * *",
      "command": "python3 scripts/cleanup_deleted_videos.py"
    }
  ]
}
```

Create `backend/scripts/cleanup_deleted_videos.py`:
```python
"""
Permanently delete videos that have been soft-deleted for 30+ days.
Runs daily at 00:00 UTC via Railway cron.
"""
import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models import Video

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def cleanup_old_deleted_videos():
    """Permanently delete videos deleted more than 30 days ago."""
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async with async_session() as session:
        # Calculate cutoff date (30 days ago)
        cutoff_date = datetime.now(timezone.utc) - timedelta(days=30)

        # Find videos to delete
        result = await session.execute(
            select(Video).where(
                Video.deleted_at != None,
                Video.deleted_at < cutoff_date
            )
        )
        videos_to_delete = result.scalars().all()

        if not videos_to_delete:
            logger.info("No videos to permanently delete")
            return

        # Delete them
        stmt = delete(Video).where(
            Video.deleted_at != None,
            Video.deleted_at < cutoff_date
        )
        result = await session.execute(stmt)
        await session.commit()

        count = result.rowcount
        logger.info(f"Permanently deleted {count} videos older than 30 days")

        # Log some details
        for video in videos_to_delete[:5]:  # Log first 5
            days_since_deletion = (datetime.now(timezone.utc) - video.deleted_at).days
            logger.info(
                f"  - Video {video.id}: deleted {days_since_deletion} days ago"
            )

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(cleanup_old_deleted_videos())
```

#### Option 2: GitHub Actions Cron

Create `.github/workflows/cleanup-deleted-videos.yml`:
```yaml
name: Cleanup Deleted Videos

on:
  schedule:
    - cron: '0 0 * * *'  # Daily at 00:00 UTC
  workflow_dispatch:  # Allow manual trigger

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt

      - name: Run cleanup script
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          cd backend
          python3 scripts/cleanup_deleted_videos.py
```

## Testing Checklist

### Wave 4: Soft Delete

- [ ] Soft delete video → verify `deleted_at` is set
- [ ] List videos → verify soft-deleted videos are excluded
- [ ] List with `deleted=true` → verify soft-deleted videos appear
- [ ] List with `deleted=true` → verify only last 30 days
- [ ] Restore video → verify `deleted_at` is cleared
- [ ] Try to restore video >30 days old → verify 410 error
- [ ] Permanent delete → verify video is immediately removed
- [ ] Search videos → verify soft-deleted excluded
- [ ] Get video by ID → verify soft-deleted returns 404
- [ ] Bulk delete → verify soft delete behavior
- [ ] Bulk move → verify excludes soft-deleted videos

### Wave 5: Tags

- [ ] GET /videos/tags → verify returns all tags with counts
- [ ] GET /videos/tags → verify sorted by count DESC
- [ ] GET /videos?tag={name} → verify filters correctly
- [ ] Soft delete video → verify tag counts update
- [ ] Restore video → verify tag counts update

### Cron Job

- [ ] Run cleanup script manually → verify old videos deleted
- [ ] Check logs → verify count and details logged
- [ ] Verify cron schedule configured correctly
- [ ] Test with videos exactly 30 days old (boundary condition)

## Migration Rollback

If needed, rollback migration:
```bash
cd backend
python3 -m alembic downgrade -1
```

This will:
1. Drop the `ix_videos_deleted_at` index
2. Drop the `deleted_at` column

**Note:** Any soft-deleted videos will become active again if rolled back!

## Performance Considerations

1. **Index Usage**: Partial index on `deleted_at` ensures fast queries for deleted videos
2. **Query Scoping**: All queries add `WHERE deleted_at IS NULL` - minimal overhead
3. **Tags Aggregation**: Uses PostgreSQL `UNNEST` for efficient tag counting
4. **Bulk Operations**: Modified to use SQLAlchemy bulk updates instead of hard delete

## Future Enhancements

1. **Email Notifications**: Warn users 3 days before permanent deletion
2. **Restore from Email**: One-click restore link in notification email
3. **Admin Dashboard**: View all deleted videos across users
4. **Configurable Retention**: Let Pro users set custom retention period (60/90 days)
5. **Bulk Restore**: Restore multiple videos at once from Recently Deleted
