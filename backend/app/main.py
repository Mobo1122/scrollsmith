"""FastAPI application entry point."""

from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from asgi_correlation_id import CorrelationIdMiddleware

from app.core.config import settings
from app.core.database import async_engine
from app.core.logging import configure_logging
from app.core.sentry import init_sentry
from app.api.v1 import api_router


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Manage application lifespan events.

    Args:
        app: The FastAPI application instance.

    Yields:
        None: Control during application runtime.
    """
    # Configure structured logging
    configure_logging()
    # Initialize Sentry error monitoring
    init_sentry()
    # Startup: engine is already created
    print(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    print(f"Environment: {settings.ENVIRONMENT}")
    yield
    # Shutdown: dispose of the engine
    await async_engine.dispose()
    print("Engine disposed, shutting down")


# Create FastAPI application
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Backend API for Scrollsmith - Transform video hoarding into action",
    lifespan=lifespan,
)

# Configure CORS for iOS local testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add correlation ID to all requests
app.add_middleware(CorrelationIdMiddleware)

# Include API routers
app.include_router(api_router, prefix="/api/v1")


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
    }


@app.get("/terms")
async def terms_of_service():
    """Serve Terms of Service HTML page."""
    return FileResponse("app/static/legal/terms.html", media_type="text/html")


@app.get("/privacy")
async def privacy_policy():
    """Serve Privacy Policy HTML page."""
    return FileResponse("app/static/legal/privacy.html", media_type="text/html")
