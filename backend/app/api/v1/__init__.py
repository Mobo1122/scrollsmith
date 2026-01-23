"""API v1 router."""

from fastapi import APIRouter

from app.api.v1.endpoints import auth, health, playbooks, videos

# Create v1 router
api_router = APIRouter()

# Include endpoint routers
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router)
api_router.include_router(playbooks.router)
api_router.include_router(videos.router)
