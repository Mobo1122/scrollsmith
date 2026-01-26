"""Streak calculation service with 1-day forgiveness.

Streak forgiveness means: if user misses exactly 1 day, streak continues.
Two or more consecutive missed days breaks the streak.
"""

import logging
from uuid import UUID
from typing import Tuple

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)


async def calculate_streaks_with_forgiveness(
    db: AsyncSession,
    habit_id: UUID,
    user_timezone: str = "UTC"
) -> Tuple[int, int]:
    """Calculate current and longest streak with 1-day forgiveness.

    Args:
        db: Database session
        habit_id: The habit to calculate streaks for
        user_timezone: IANA timezone identifier for day boundary calculation

    Returns:
        Tuple of (current_streak, longest_streak)
    """
    query = text("""
        WITH completion_dates AS (
            SELECT DISTINCT
                (completed_at AT TIME ZONE :tz)::date AS completion_date
            FROM habit_completions
            WHERE habit_id = :habit_id
            ORDER BY completion_date
        ),
        with_gaps AS (
            SELECT
                completion_date,
                completion_date - LAG(completion_date) OVER (ORDER BY completion_date) AS gap
            FROM completion_dates
        ),
        streak_groups AS (
            SELECT
                completion_date,
                gap,
                SUM(CASE WHEN gap IS NULL OR gap <= 2 THEN 0 ELSE 1 END)
                    OVER (ORDER BY completion_date) AS streak_id
            FROM with_gaps
        ),
        streaks AS (
            SELECT
                streak_id,
                COUNT(*) AS streak_length,
                MAX(completion_date) AS streak_end
            FROM streak_groups
            GROUP BY streak_id
        )
        SELECT
            COALESCE(
                (SELECT streak_length FROM streaks
                 WHERE streak_end >= (CURRENT_DATE AT TIME ZONE :tz)::date - INTERVAL '1 day'
                 ORDER BY streak_end DESC LIMIT 1),
                0
            )::integer AS current_streak,
            COALESCE(MAX(streak_length), 0)::integer AS longest_streak
        FROM streaks
    """)

    result = await db.execute(
        query,
        {"habit_id": str(habit_id), "tz": user_timezone}
    )
    row = result.fetchone()

    if row is None:
        return 0, 0

    logger.debug(f"Streak for habit {habit_id}: current={row.current_streak}, longest={row.longest_streak}")
    return row.current_streak, row.longest_streak
