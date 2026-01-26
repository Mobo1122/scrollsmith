"""Application configuration using Pydantic Settings v2."""

import os
from typing import Optional

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database - can be set directly or built from PG* variables
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/scrollsmith"

    # Individual PG variables (Railway sets these)
    PGHOST: Optional[str] = None
    PGPORT: Optional[str] = None
    PGUSER: Optional[str] = None
    PGPASSWORD: Optional[str] = None
    PGDATABASE: Optional[str] = None

    # Application
    ENVIRONMENT: str = "development"
    APP_NAME: str = "Scrollsmith"
    APP_VERSION: str = "0.1.0"
    APP_URL: str = "http://localhost:8000"

    # JWT Authentication
    JWT_SECRET: str = "dev-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Email (Resend)
    RESEND_API_KEY: Optional[str] = None

    # Apple Sign In
    APPLE_BUNDLE_ID: str = "com.scrollsmith.app"

    # YouTube Data API
    YOUTUBE_API_KEY: Optional[str] = None

    # OpenAI (Whisper transcription)
    OPENAI_API_KEY: Optional[str] = None

    # AssemblyAI (alternative transcription)
    ASSEMBLYAI_API_KEY: Optional[str] = None

    # Anthropic Claude API (AI summarization)
    ANTHROPIC_API_KEY: Optional[str] = None

    # RevenueCat (subscriptions)
    REVENUECAT_WEBHOOK_AUTH_KEY: Optional[str] = None
    REVENUECAT_API_KEY: Optional[str] = None

    # Free tier limits
    FREE_TIER_VIDEO_LIMIT: int = 10

    @model_validator(mode="after")
    def build_database_url_from_pg_vars(self) -> "Settings":
        """Build DATABASE_URL from individual PG* variables if they exist."""
        # If all PG variables are set, build the URL from them
        if all([self.PGHOST, self.PGPORT, self.PGUSER, self.PGPASSWORD, self.PGDATABASE]):
            self.DATABASE_URL = (
                f"postgresql+asyncpg://{self.PGUSER}:{self.PGPASSWORD}"
                f"@{self.PGHOST}:{self.PGPORT}/{self.PGDATABASE}"
            )
        return self

    @field_validator("DATABASE_URL", mode="after")
    @classmethod
    def convert_to_async_url(cls, v: str) -> str:
        """Convert standard postgresql:// URL to postgresql+asyncpg:// for async engine.

        Railway and other providers often supply DATABASE_URL with postgresql:// scheme,
        but SQLAlchemy's async engine requires postgresql+asyncpg://.
        """
        if v.startswith("postgresql://"):
            return v.replace("postgresql://", "postgresql+asyncpg://", 1)
        return v

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
    )


# Global settings instance
settings = Settings()
