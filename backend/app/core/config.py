"""Application configuration using Pydantic Settings v2."""

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/scrollsmith"

    # Application
    ENVIRONMENT: str = "development"
    APP_NAME: str = "Scrollsmith"
    APP_VERSION: str = "0.1.0"

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
