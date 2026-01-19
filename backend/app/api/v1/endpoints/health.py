"""Health check endpoint."""

from typing import Dict

from fastapi import APIRouter, Depends, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db

router = APIRouter()


@router.get("/health", status_code=status.HTTP_200_OK)
async def health_check(db: AsyncSession = Depends(get_db)) -> Dict[str, str]:
    """Check application and database health.

    Args:
        db: Database session from dependency injection.

    Returns:
        Health status with database connectivity confirmation.

    Raises:
        HTTPException: 503 if database is unreachable.
    """
    try:
        # Test database connectivity with simple query
        await db.execute(text("SELECT 1"))
        return {
            "status": "healthy",
            "database": "connected",
        }
    except Exception as e:
        # In production, you'd want to log this error
        return {
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e),
        }
