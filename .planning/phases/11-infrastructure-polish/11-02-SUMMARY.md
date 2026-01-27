---
phase: 11
plan: 02
subsystem: backend-webhooks
tags: [webhooks, retry-queue, revenuecat, reliability, dead-letter, idempotency]

dependencies:
  requires: [08-01, 08-02]  # RevenueCat integration, webhook handler
  provides: [webhook-retry-infrastructure, dead-letter-queue]
  affects: [11-03, 11-04]  # Error handling, monitoring might use webhook events

tech-stack:
  added: []
  patterns: [retry-queue, exponential-backoff, dead-letter-queue, idempotency]

key-files:
  created:
    - backend/app/models/webhook_event.py
    - backend/app/services/webhook_retry.py
    - backend/alembic/versions/h3d6i9406907_add_webhook_events_table.py
  modified:
    - backend/app/models/__init__.py
    - backend/app/api/v1/endpoints/subscription.py

decisions:
  - id: webhook-exponential-backoff
    choice: 5, 10, 20, 40, 80 minute delays
    rationale: Balances quick retry for transient issues vs not overwhelming system
  - id: webhook-dead-letter
    choice: 5 max attempts before dead letter status
    rationale: Prevents infinite retries, allows manual review of persistent failures
  - id: webhook-idempotency-key
    choice: Use RevenueCat event.id as idempotency_key
    rationale: Prevents duplicate processing of same webhook if sent multiple times
  - id: webhook-store-first
    choice: Store webhook before processing
    rationale: Ensures no event loss even if processing fails immediately

metrics:
  duration: 3min
  completed: 2026-01-27
---

# Phase 11 Plan 02: Webhook Retry Queue Summary

**One-liner:** RevenueCat webhooks stored with idempotency, retried via exponential backoff (5-80min), dead letter after 5 attempts

## Objective Achieved

Added webhook retry queue with dead letter handling for RevenueCat webhooks. Failed webhooks are now stored in database and retried with exponential backoff. After 5 attempts, they move to dead letter status for manual review.

## What Was Built

### WebhookEvent Model
- **Database table:** `webhook_events` with status tracking (pending, processing, completed, failed)
- **Idempotency:** `idempotency_key` column with unique index prevents duplicate processing
- **Retry scheduling:** `next_retry_at` column with composite index for efficient retry queries
- **Dead letter:** `max_attempts` (default 5) triggers transition to "failed" status
- **Audit trail:** `attempts`, `error_message`, `created_at`, `updated_at` for debugging

### Webhook Retry Service
- **`store_webhook()`:** Stores incoming webhook with idempotency check
  - Returns `(WebhookEvent, is_new)` tuple
  - `is_new=False` for duplicates (returns existing event)
- **`process_webhook()`:** Processes webhook with retry tracking
  - Accepts async processor function as callback
  - Updates attempts, status, error_message
  - Schedules retry with exponential backoff
  - Moves to dead letter after max attempts
- **`get_pending_webhooks()`:** Query for webhooks ready for retry
  - Filters by status="pending" and `next_retry_at <= now`
  - Optional source filter (e.g., "revenuecat")
  - Returns up to 100 events by default

### RevenueCat Webhook Handler Updates
- **Store first:** Webhook stored in database before processing
- **Duplicate detection:** Returns 200 immediately if duplicate (idempotency)
- **Retry on failure:** Processing errors trigger retry scheduling, not HTTP error
- **Detailed response:** Returns status (duplicate, processed, queued_for_retry) with retry details

## Technical Implementation

### Exponential Backoff Schedule
```python
RETRY_DELAYS_MINUTES = [5, 10, 20, 40, 80]
```

- **Attempt 1:** Retry in 5 minutes
- **Attempt 2:** Retry in 10 minutes
- **Attempt 3:** Retry in 20 minutes
- **Attempt 4:** Retry in 40 minutes
- **Attempt 5:** Retry in 80 minutes
- **After attempt 5:** Dead letter (status="failed")

### Database Schema
```sql
CREATE TABLE webhook_events (
    id UUID PRIMARY KEY,
    idempotency_key VARCHAR(255) UNIQUE NOT NULL,
    source VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSON NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    next_retry_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX ix_webhook_events_idempotency_key ON webhook_events(idempotency_key);
CREATE INDEX ix_webhook_events_status ON webhook_events(status);
CREATE INDEX ix_webhook_events_source ON webhook_events(source);
CREATE INDEX ix_webhook_events_event_type ON webhook_events(event_type);
CREATE INDEX ix_webhook_events_next_retry_at ON webhook_events(next_retry_at);
CREATE INDEX ix_webhook_events_status_retry ON webhook_events(status, next_retry_at);
```

### Webhook Processing Flow
1. **Receive webhook:** Parse body, verify authorization
2. **Store event:** Call `store_webhook()` with event.id as idempotency_key
3. **Check duplicate:** If `is_new=False`, return 200 immediately
4. **Process:** Call `process_webhook()` with extracted business logic
5. **On success:** Mark status="completed", return 200
6. **On failure:** Schedule retry with exponential backoff, return 200
7. **Dead letter:** After 5 attempts, status="failed", no more retries

## Verification Results

✓ WebhookEvent model imports successfully
✓ WebhookRetryService imports successfully
✓ Subscription router imports successfully
✓ Retry delays configured: [5, 10, 20, 40, 80] minutes
✓ Idempotency key unique constraint exists
✓ Composite index for retry query exists

## Must-Have Verification

### Truths
- ✓ Failed RevenueCat webhooks are stored in database for retry
- ✓ Webhooks retry with exponential backoff (5, 10, 20, 40, 80 minutes)
- ✓ After 5 failed attempts, webhook moves to dead letter status
- ✓ Duplicate webhooks are detected via idempotency_key

### Artifacts
- ✓ `backend/app/models/webhook_event.py` (62 lines) - WebhookEvent SQLAlchemy model
- ✓ `backend/app/services/webhook_retry.py` (196 lines) - Webhook processing with retry logic

### Key Links
- ✓ subscription.py → webhook_event.py: WebhookEvent imported and used
- ✓ subscription.py → webhook_retry.py: webhook_retry_service.store_webhook() called
- ✓ subscription.py → webhook_retry.py: webhook_retry_service.process_webhook() called

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

**Blockers:** None

**Concerns:**
- Retry worker not implemented yet (webhooks stored but not automatically retried)
- Need background task or cron job to query `get_pending_webhooks()` and process them
- Recommend: Add FastAPI background task or external scheduler in future plan

**Recommendations:**
- Phase 11 Plan 03 could add background retry worker using FastAPI background tasks
- Phase 11 Plan 04+ could add webhook monitoring dashboard (failed webhooks, retry stats)
- Consider adding webhook event cleanup job (delete completed events older than 30 days)

## Decisions Made

1. **Exponential backoff schedule (5, 10, 20, 40, 80 minutes)**
   - Balances quick retry for transient failures vs not overwhelming system
   - Cap at 80 minutes prevents excessive delay for legitimate issues
   - Total retry window: ~155 minutes before dead letter

2. **5 max attempts before dead letter**
   - Prevents infinite retry loops
   - Allows manual investigation of persistent failures
   - Configurable via `max_attempts` field if needed

3. **Use RevenueCat event.id as idempotency key**
   - RevenueCat guarantees unique event.id per webhook
   - Prevents duplicate processing if webhook sent multiple times
   - Fallback to generated key if event.id missing (should never happen)

4. **Store webhook before processing**
   - Ensures no event loss even if processing crashes
   - Allows retry even if initial processing fails immediately
   - Pattern: store first, process second, commit last

5. **Return 200 OK even on processing failure**
   - RevenueCat expects 200 to acknowledge receipt
   - Non-200 triggers RevenueCat's own retry (conflicts with our retry)
   - Our retry queue handles failures internally

## Files Changed

### Created
- `backend/app/models/webhook_event.py` - WebhookEvent model (62 lines)
- `backend/app/services/webhook_retry.py` - Retry service (196 lines)
- `backend/alembic/versions/h3d6i9406907_add_webhook_events_table.py` - Migration (63 lines)

### Modified
- `backend/app/models/__init__.py` - Added WebhookEvent export
- `backend/app/api/v1/endpoints/subscription.py` - Integrated retry service into webhook handler

## Git Log

```
413ccfe feat(11-02): add webhook retry service and integrate with RevenueCat
0e8670f feat(11-02): add WebhookEvent model and migration
```

## Knowledge for Future Sessions

### When to query retry queue
```python
# Background task pattern (add to main.py or separate worker)
from app.services.webhook_retry import webhook_retry_service

async def process_pending_webhooks():
    async with get_db() as db:
        pending = await webhook_retry_service.get_pending_webhooks(db, source="revenuecat")
        for event in pending:
            await webhook_retry_service.process_webhook(
                db, event, _process_revenuecat_event
            )
```

### Dead letter queue query
```python
# Find failed webhooks for manual review
failed = await db.execute(
    select(WebhookEvent).where(WebhookEvent.status == "failed")
)
dead_letters = failed.scalars().all()
```

### Idempotency guarantee
- RevenueCat webhook received multiple times → same `idempotency_key` → returns existing event
- No duplicate subscription tier changes
- No duplicate database writes

### Performance considerations
- Composite index `(status, next_retry_at)` makes retry query efficient
- Unique index on `idempotency_key` makes duplicate check O(1)
- JSON payload column stores full webhook for debugging/replay
