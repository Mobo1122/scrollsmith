"""
Permanently delete videos that have been soft-deleted for 30+ days.

Runs daily at 00:00 UTC via Railway cron job or GitHub Actions.

Usage:
    python3 scripts/cleanup_deleted_videos.py

Environment Variables Required:
    DATABASE_URL - PostgreSQL connection string
"""
import asyncio
import logging
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models import Video

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def cleanup_old_deleted_videos():
    """Permanently delete videos deleted more than 30 days ago.

    Returns:
        int: Number of videos permanently deleted
    """
    logger.info("Starting cleanup of deleted videos older than 30 days")

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    try:
        async with async_session() as session:
            # Calculate cutoff date (30 days ago from now)
            cutoff_date = datetime.now(timezone.utc) - timedelta(days=30)
            logger.info(f"Cutoff date: {cutoff_date.isoformat()}")

            # Find videos to delete (for logging purposes)
            result = await session.execute(
                select(Video).where(
                    Video.deleted_at != None,
                    Video.deleted_at < cutoff_date
                )
            )
            videos_to_delete = result.scalars().all()

            if not videos_to_delete:
                logger.info("No videos found for permanent deletion")
                return 0

            logger.info(f"Found {len(videos_to_delete)} videos to permanently delete")

            # Log details of first 10 videos (for debugging)
            for video in videos_to_delete[:10]:
                days_since_deletion = (datetime.now(timezone.utc) - video.deleted_at).days
                logger.info(
                    f"  - Video {video.id} (user {video.user_id}): "
                    f"deleted {days_since_deletion} days ago on {video.deleted_at.date()}"
                )

            if len(videos_to_delete) > 10:
                logger.info(f"  ... and {len(videos_to_delete) - 10} more")

            # Permanently delete them
            stmt = delete(Video).where(
                Video.deleted_at != None,
                Video.deleted_at < cutoff_date
            )
            result = await session.execute(stmt)
            await session.commit()

            count = result.rowcount
            logger.info(f"✓ Successfully permanently deleted {count} videos")

            return count

    except Exception as e:
        logger.error(f"Error during cleanup: {e}", exc_info=True)
        raise

    finally:
        await engine.dispose()
        logger.info("Database connection closed")


async def main():
    """Main entry point."""
    try:
        count = await cleanup_old_deleted_videos()
        logger.info(f"Cleanup completed: {count} videos deleted")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Cleanup failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
