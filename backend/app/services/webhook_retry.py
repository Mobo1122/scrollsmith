"""Webhook retry service with exponential backoff.

Handles:
- Storing incoming webhooks with idempotency check
- Processing webhooks with retry logic
- Dead letter queue for max-attempt failures
- Retry scheduling with exponential backoff (5, 10, 20, 40, 80 min)
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, Callable, Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.webhook_event import WebhookEvent

logger = logging.getLogger(__name__)

# Exponential backoff delays in minutes: 5, 10, 20, 40, 80
RETRY_DELAYS_MINUTES = [5, 10, 20, 40, 80]


class WebhookRetryService:
    """Service for reliable webhook processing with retry queue."""

    async def store_webhook(
        self,
        db: AsyncSession,
        idempotency_key: str,
        source: str,
        event_type: str,
        payload: dict,
    ) -> tuple[WebhookEvent, bool]:
        """Store incoming webhook for processing.

        Args:
            db: Database session
            idempotency_key: Unique event identifier (e.g., RevenueCat event.id)
            source: Webhook source (e.g., 'revenuecat')
            event_type: Event type (e.g., 'INITIAL_PURCHASE')
            payload: Full webhook payload

        Returns:
            Tuple of (WebhookEvent, is_new). is_new is False if duplicate.
        """
        # Check for existing event (idempotency)
        result = await db.execute(
            select(WebhookEvent).where(WebhookEvent.idempotency_key == idempotency_key)
        )
        existing = result.scalar_one_or_none()

        if existing:
            logger.info(
                "webhook_duplicate",
                extra={"idempotency_key": idempotency_key, "existing_status": existing.status},
            )
            return existing, False

        # Create new event
        event = WebhookEvent(
            idempotency_key=idempotency_key,
            source=source,
            event_type=event_type,
            payload=payload,
            status="pending",
            attempts=0,
        )
        db.add(event)
        await db.flush()

        logger.info(
            "webhook_stored",
            extra={"event_id": str(event.id), "source": source, "event_type": event_type},
        )
        return event, True

    async def process_webhook(
        self,
        db: AsyncSession,
        event: WebhookEvent,
        processor: Callable[[dict], Any],
    ) -> bool:
        """Process a webhook event with retry tracking.

        Args:
            db: Database session
            event: Webhook event to process
            processor: Async function to process the payload

        Returns:
            True if processing succeeded, False otherwise.
        """
        # Skip already completed events
        if event.status == "completed":
            return True

        # Skip dead letter events
        if event.status == "failed":
            logger.warning(
                "webhook_skip_failed",
                extra={"event_id": str(event.id), "attempts": event.attempts},
            )
            return False

        # Mark as processing
        event.status = "processing"
        event.attempts += 1
        event.updated_at = datetime.now(timezone.utc)
        await db.flush()

        try:
            # Call the processor
            await processor(event.payload)

            # Success
            event.status = "completed"
            event.next_retry_at = None
            event.error_message = None
            await db.commit()

            logger.info(
                "webhook_completed",
                extra={"event_id": str(event.id), "attempts": event.attempts},
            )
            return True

        except Exception as e:
            error_msg = str(e)
            logger.error(
                "webhook_processing_error",
                extra={"event_id": str(event.id), "attempts": event.attempts, "error": error_msg},
            )

            if event.attempts >= event.max_attempts:
                # Dead letter - max attempts reached
                event.status = "failed"
                event.error_message = f"Max attempts ({event.max_attempts}) reached. Last error: {error_msg}"
                event.next_retry_at = None
                logger.warning(
                    "webhook_dead_letter",
                    extra={"event_id": str(event.id), "attempts": event.attempts},
                )
            else:
                # Schedule retry with exponential backoff
                delay_index = min(event.attempts - 1, len(RETRY_DELAYS_MINUTES) - 1)
                delay_minutes = RETRY_DELAYS_MINUTES[delay_index]
                event.status = "pending"
                event.next_retry_at = datetime.now(timezone.utc) + timedelta(minutes=delay_minutes)
                event.error_message = error_msg
                logger.info(
                    "webhook_retry_scheduled",
                    extra={"event_id": str(event.id), "retry_in_minutes": delay_minutes, "next_attempt": event.attempts + 1},
                )

            await db.commit()
            return False

    async def get_pending_webhooks(
        self,
        db: AsyncSession,
        source: Optional[str] = None,
        limit: int = 100,
    ) -> list[WebhookEvent]:
        """Get webhooks ready for retry.

        Args:
            db: Database session
            source: Optional filter by source
            limit: Max events to return

        Returns:
            List of webhook events ready for processing.
        """
        now = datetime.now(timezone.utc)

        query = select(WebhookEvent).where(
            WebhookEvent.status == "pending",
            (WebhookEvent.next_retry_at == None) | (WebhookEvent.next_retry_at <= now),
        ).order_by(WebhookEvent.created_at).limit(limit)

        if source:
            query = query.where(WebhookEvent.source == source)

        result = await db.execute(query)
        return list(result.scalars().all())


# Singleton instance
webhook_retry_service = WebhookRetryService()
