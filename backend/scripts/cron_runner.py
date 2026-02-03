"""
Continuous cron runner for Railway deployment.
Runs cleanup job once per day at 00:00 UTC.

This approach works on any Railway plan without needing native cron support.
"""
import asyncio
import logging
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

# Import the cleanup function
from scripts.cleanup_deleted_videos import cleanup_old_deleted_videos

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def wait_until_midnight():
    """Calculate seconds until next midnight UTC and sleep."""
    now = datetime.now(timezone.utc)
    # Calculate tomorrow's midnight
    tomorrow = now.replace(hour=0, minute=0, second=0, microsecond=0)
    if now.hour >= 0:  # If it's any time today, wait until tomorrow midnight
        tomorrow = tomorrow + timedelta(days=1)

    seconds_until_midnight = (tomorrow - now).total_seconds()

    logger.info(f"Waiting {seconds_until_midnight/3600:.1f} hours until next run at {tomorrow.isoformat()}")
    await asyncio.sleep(seconds_until_midnight)


async def run_daily_cleanup():
    """Run cleanup job once per day at midnight UTC."""
    logger.info("=== Cron Runner Started ===")
    logger.info("Running cleanup job daily at 00:00 UTC")

    # Run immediately on startup (useful for testing)
    logger.info("Running initial cleanup...")
    try:
        count = await cleanup_old_deleted_videos()
        logger.info(f"Initial cleanup completed: {count} videos deleted")
    except Exception as e:
        logger.error(f"Initial cleanup failed: {e}", exc_info=True)

    # Then run daily at midnight
    while True:
        try:
            # Wait until midnight UTC
            await wait_until_midnight()

            # Run cleanup
            logger.info("=== Running scheduled cleanup ===")
            count = await cleanup_old_deleted_videos()
            logger.info(f"Scheduled cleanup completed: {count} videos deleted")

        except Exception as e:
            logger.error(f"Cleanup failed: {e}", exc_info=True)
            # Wait 1 hour before retrying if there's an error
            logger.info("Waiting 1 hour before retry due to error")
            await asyncio.sleep(3600)


if __name__ == "__main__":
    try:
        asyncio.run(run_daily_cleanup())
    except KeyboardInterrupt:
        logger.info("Cron runner stopped by user")
    except Exception as e:
        logger.error(f"Cron runner crashed: {e}", exc_info=True)
        sys.exit(1)
