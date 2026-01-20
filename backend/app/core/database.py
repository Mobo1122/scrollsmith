"""Async SQLAlchemy 2.0 database setup."""

from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

# Determine if we need SSL based on the database URL
# Railway's public proxy (maglev.proxy.rlwy.net) requires SSL
# Railway's internal networking (*.railway.internal) doesn't
_needs_ssl = "proxy.rlwy.net" in settings.DATABASE_URL or "maglev" in settings.DATABASE_URL

# Configure SSL for public connections
# Using "prefer" tells asyncpg to try SSL but accept non-SSL if server doesn't support
_connect_args = {}
if _needs_ssl:
    _connect_args = {"ssl": "prefer"}

# Create async engine with connection pool
async_engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.ENVIRONMENT == "development",
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,  # Verify connections before using
    connect_args=_connect_args,
)

# Create async session maker
async_session_maker = async_sessionmaker(
    async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Base class for all ORM models."""

    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency that provides an async database session.

    Yields:
        AsyncSession: Database session for the request.
    """
    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()
