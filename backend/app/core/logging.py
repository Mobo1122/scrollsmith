"""Structured logging configuration using structlog.

Provides JSON-formatted logs in production with correlation IDs
for request tracking across the application.
"""

import logging
import structlog
from asgi_correlation_id.context import correlation_id

from app.core.config import settings


def add_correlation_id(logger, method_name, event_dict):
    """Add request correlation ID to all log entries."""
    request_id = correlation_id.get()
    if request_id:
        event_dict["correlation_id"] = request_id
    return event_dict


def configure_logging():
    """Configure structlog for FastAPI with JSON output in production.

    Call this once at application startup.
    """
    # Configure standard library logging
    logging.basicConfig(
        format="%(message)s",
        level=logging.INFO,
    )

    # Determine processors based on environment
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        add_correlation_id,
    ]

    if settings.ENVIRONMENT == "production":
        # JSON for Railway log aggregation
        shared_processors.append(structlog.processors.JSONRenderer())
    else:
        # Pretty console output for development
        shared_processors.append(structlog.dev.ConsoleRenderer())

    structlog.configure(
        processors=shared_processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str):
    """Get a structlog logger instance.

    Args:
        name: Logger name (typically __name__)

    Returns:
        Configured structlog logger
    """
    return structlog.get_logger(name)
