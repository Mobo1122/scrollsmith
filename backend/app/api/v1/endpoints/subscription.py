"""Subscription and usage tracking endpoints.

Handles:
- GET /subscriptions/usage - Current usage status
- POST /webhooks/revenuecat - RevenueCat webhook handler
"""

import logging
from datetime import datetime, timezone
from dateutil.relativedelta import relativedelta

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.models import User
from app.schemas.subscription import UsageResponse, SubscriptionSyncResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/subscriptions", tags=["subscription"])


def get_next_reset_date() -> datetime:
    """Calculate the 1st of next month at midnight UTC."""
    now = datetime.now(timezone.utc)
    return (now + relativedelta(months=1)).replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def check_and_reset_usage(user: User) -> bool:
    """Check if usage should reset and reset if needed.

    Returns True if usage was reset.
    """
    if user.subscription_tier == "pro":
        return False

    now = datetime.now(timezone.utc)

    # Initialize reset date if not set
    if user.usage_reset_date is None:
        user.usage_reset_date = get_next_reset_date()
        return False

    # Reset if past reset date
    if now >= user.usage_reset_date:
        user.videos_this_month = 0
        user.usage_reset_date = get_next_reset_date()
        logger.info(f"Reset usage for user {user.id}, next reset: {user.usage_reset_date}")
        return True

    return False


@router.get("/usage", response_model=UsageResponse)
async def get_usage(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UsageResponse:
    """Get current usage status for the authenticated user.

    Returns:
        - Videos used this month
        - Video limit (10 for free, -1 for pro/unlimited)
        - Whether user can create more videos
        - Next reset date (ISO8601 string)
        - Whether user has Pro subscription
    """
    # Check if usage needs reset
    was_reset = check_and_reset_usage(current_user)
    if was_reset:
        await db.commit()
        await db.refresh(current_user)

    is_pro = current_user.subscription_tier == "pro"
    limit = -1 if is_pro else settings.FREE_TIER_VIDEO_LIMIT
    can_create = is_pro or current_user.videos_this_month < settings.FREE_TIER_VIDEO_LIMIT

    # Format reset date as ISO8601 string
    reset_date_str = None
    if current_user.usage_reset_date and not is_pro:
        reset_date_str = current_user.usage_reset_date.isoformat()

    return UsageResponse(
        videos_used=current_user.videos_this_month,
        videos_limit=limit,
        can_create_video=can_create,
        reset_date=reset_date_str,
        is_pro=is_pro,
    )


@router.post("/webhooks/revenuecat", status_code=status.HTTP_200_OK)
async def revenuecat_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    authorization: str = Header(None, alias="Authorization"),
) -> dict:
    """Handle RevenueCat webhook events.

    Events handled:
    - INITIAL_PURCHASE: User subscribed -> set tier to 'pro'
    - RENEWAL: Subscription renewed -> ensure tier is 'pro'
    - CANCELLATION: User cancelled (still active until period end)
    - EXPIRATION: Subscription expired -> set tier to 'free'
    - BILLING_ISSUE: Payment failed (still active until grace period ends)

    Security: Requires Authorization header matching REVENUECAT_WEBHOOK_AUTH_KEY.

    See: https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
    """
    # Verify webhook authorization
    expected_auth = settings.REVENUECAT_WEBHOOK_AUTH_KEY
    if not expected_auth:
        logger.warning("REVENUECAT_WEBHOOK_AUTH_KEY not configured, rejecting webhook")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Webhook handler not configured"
        )

    # RevenueCat sends "Bearer <key>" format
    if not authorization:
        logger.warning("RevenueCat webhook missing Authorization header")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authorization")

    # Handle both "Bearer <key>" and plain "<key>" formats
    auth_key = authorization.replace("Bearer ", "") if authorization.startswith("Bearer ") else authorization
    if auth_key != expected_auth:
        logger.warning("RevenueCat webhook invalid authorization")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authorization")

    # Parse webhook body
    try:
        body = await request.json()
    except Exception as e:
        logger.error(f"Failed to parse RevenueCat webhook body: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid JSON body")

    # Extract event data
    event = body.get("event", {})
    event_type = event.get("type")
    app_user_id = event.get("app_user_id")

    if not event_type or not app_user_id:
        logger.warning(f"RevenueCat webhook missing required fields: type={event_type}, app_user_id={app_user_id}")
        return {"status": "ignored", "reason": "missing required fields"}

    logger.info(f"RevenueCat webhook: {event_type} for user {app_user_id}")

    # Find user by ID (RevenueCat app_user_id is the user's UUID)
    from sqlalchemy import select
    from uuid import UUID

    try:
        user_id = UUID(app_user_id)
    except ValueError:
        # app_user_id might be a RevenueCat anonymous ID for unidentified users
        logger.info(f"Ignoring webhook for non-UUID app_user_id: {app_user_id}")
        return {"status": "ignored", "reason": "anonymous user"}

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        logger.warning(f"RevenueCat webhook for unknown user: {user_id}")
        return {"status": "ignored", "reason": "user not found"}

    # Handle event types
    old_tier = user.subscription_tier

    if event_type in ["INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION"]:
        # User has active subscription
        user.subscription_tier = "pro"
        logger.info(f"User {user_id} upgraded to pro via {event_type}")

    elif event_type in ["EXPIRATION", "BILLING_ISSUE"]:
        # Subscription ended or payment failed
        # Note: BILLING_ISSUE might have a grace period, but we downgrade immediately
        # RevenueCat will send RENEWAL if payment succeeds during grace period
        user.subscription_tier = "free"
        # Initialize usage tracking for free tier
        if user.usage_reset_date is None:
            user.usage_reset_date = get_next_reset_date()
        logger.info(f"User {user_id} downgraded to free via {event_type}")

    elif event_type == "CANCELLATION":
        # User cancelled but subscription still active until period end
        # Don't change tier - wait for EXPIRATION event
        logger.info(f"User {user_id} cancelled subscription (still active)")

    elif event_type == "SUBSCRIBER_ALIAS":
        # User IDs merged - typically for anonymous -> identified
        logger.info(f"Subscriber alias event for user {user_id}")

    else:
        logger.info(f"Unhandled RevenueCat event type: {event_type}")

    # Commit changes
    await db.commit()

    return {
        "status": "processed",
        "event_type": event_type,
        "user_id": str(user_id),
        "tier_change": f"{old_tier} -> {user.subscription_tier}" if old_tier != user.subscription_tier else None,
    }
