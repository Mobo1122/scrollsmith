"""Sentry error monitoring initialization.

Provides FastAPI + SQLAlchemy integration for error tracking
with automatic PII scrubbing.
"""

import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

from app.core.config import settings


def scrub_sensitive_data(event, hint):
    """Remove sensitive data from Sentry events before sending.

    Scrubs authorization headers to prevent token leakage.
    """
    if "request" in event and "headers" in event["request"]:
        headers = event["request"]["headers"]
        # Scrub auth headers
        sensitive_headers = ["authorization", "x-api-key", "cookie"]
        for header in sensitive_headers:
            if header in headers:
                headers[header] = "[FILTERED]"
    return event


def init_sentry():
    """Initialize Sentry SDK with FastAPI integration.

    Only initializes if SENTRY_DSN is configured.
    Call this once at application startup.
    """
    if not settings.SENTRY_DSN:
        print("Sentry: SENTRY_DSN not configured, skipping initialization")
        return

    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.ENVIRONMENT,
        release=f"scrollsmith-backend@{settings.APP_VERSION}",
        traces_sample_rate=0.1,  # 10% of requests for performance monitoring
        integrations=[
            FastApiIntegration(transaction_style="endpoint"),
            SqlalchemyIntegration(),
        ],
        before_send=scrub_sensitive_data,
        # Don't send PII by default
        send_default_pii=False,
    )
    print(f"Sentry: Initialized for environment '{settings.ENVIRONMENT}'")
