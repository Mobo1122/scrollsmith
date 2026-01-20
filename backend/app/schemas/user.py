"""User response schemas."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr


class UserResponse(BaseModel):
    """Schema for user data returned from API."""

    id: UUID
    email: EmailStr
    email_verified: bool
    subscription_tier: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
