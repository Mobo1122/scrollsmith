"""API v1 router."""

from fastapi import APIRouter

from app.api.v1.endpoints import health

# Create v1 router
api_router = APIRouter()

# Include endpoint routers
api_router.include_router(health.router, tags=["health"])
