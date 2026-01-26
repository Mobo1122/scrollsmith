"""Subscription and usage tracking schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class UsageResponse(BaseModel):
    """Current usage status for the user.

    Field names use snake_case matching iOS CodingKeys.
    """

    videos_used: int = Field(alias="videos_used", description="Videos processed this billing period")
    videos_limit: int = Field(description="Maximum videos allowed (-1 = unlimited)")
    can_create_video: bool = Field(alias="can_create_video", description="Whether user can create more videos")
    reset_date: Optional[str] = Field(
        default=None,
        alias="reset_date",
        description="ISO8601 date when usage counter resets"
    )
    is_pro: bool = Field(alias="is_pro", description="Whether user has Pro subscription")


class RevenueCatWebhookEvent(BaseModel):
    """RevenueCat webhook event payload.

    See: https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
    """

    event: dict = Field(description="Webhook event data")
    api_version: str = Field(default="1.0")


class SubscriptionSyncResponse(BaseModel):
    """Response after syncing subscription status."""

    tier: str = Field(description="Updated subscription tier")
    updated: bool = Field(description="Whether tier was changed")
