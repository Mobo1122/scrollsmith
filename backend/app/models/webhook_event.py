"""WebhookEvent model for retry queue with dead letter handling.

Stores incoming webhooks for reliable processing with:
- Idempotency via event_id (prevents duplicate processing)
- Status tracking (pending, processing, completed, failed)
- Retry scheduling with exponential backoff
- Dead letter after max attempts
"""

from datetime import datetime
from typing import Optional
from uuid import uuid4

from sqlalchemy import Column, String, Integer, DateTime, Text, Index
from sqlalchemy.dialects.postgresql import UUID, JSON

from app.core.database import Base


class WebhookEvent(Base):
    """Webhook event for retry queue.

    Attributes:
        id: Unique ID for this webhook record
        idempotency_key: External event ID for deduplication (e.g., RevenueCat event.id)
        source: Webhook source (e.g., 'revenuecat')
        event_type: Type of event (e.g., 'INITIAL_PURCHASE')
        payload: Full webhook payload as JSON
        status: Current status (pending, processing, completed, failed)
        attempts: Number of processing attempts
        max_attempts: Maximum retry attempts before dead letter
        next_retry_at: When to retry (null if completed/failed)
        error_message: Last error message if failed
        created_at: When webhook was received
        updated_at: When record was last modified
    """

    __tablename__ = "webhook_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    idempotency_key = Column(String(255), unique=True, index=True, nullable=False)
    source = Column(String(50), nullable=False, index=True)
    event_type = Column(String(100), nullable=False, index=True)
    payload = Column(JSON, nullable=False)
    status = Column(String(20), nullable=False, default="pending", index=True)
    attempts = Column(Integer, nullable=False, default=0)
    max_attempts = Column(Integer, nullable=False, default=5)
    next_retry_at = Column(DateTime(timezone=True), nullable=True, index=True)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Composite index for retry query
    __table_args__ = (
        Index("ix_webhook_events_status_retry", "status", "next_retry_at"),
    )

    def __repr__(self):
        return f"<WebhookEvent {self.source}:{self.event_type} status={self.status}>"
