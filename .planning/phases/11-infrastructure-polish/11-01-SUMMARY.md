---
phase: 11
plan: 01
subsystem: backend-infrastructure
tags: [logging, monitoring, sentry, structlog, correlation-ids, error-tracking]
requires: [foundation, database, api-framework]
provides: [structured-logging, error-monitoring, request-tracking]
affects: [all-future-api-development, production-debugging]
tech-stack:
  added: [sentry-sdk, structlog, asgi-correlation-id]
  patterns: [structured-logging, correlation-ids, pii-scrubbing]
key-files:
  created:
    - backend/app/core/logging.py
    - backend/app/core/sentry.py
  modified:
    - backend/requirements.txt
    - backend/app/core/config.py
    - backend/app/main.py
decisions:
  - slug: json-logs-in-production
    title: JSON-formatted logs in production
    rationale: Enables Railway log aggregation and parsing
  - slug: correlation-id-middleware
    title: Correlation IDs for request tracking
    rationale: Tracks requests across distributed systems and async operations
  - slug: sentry-pii-scrubbing
    title: Automatic PII scrubbing in Sentry
    rationale: Prevents auth tokens and sensitive headers from leaking to Sentry dashboard
  - slug: 10-percent-trace-sampling
    title: 10% trace sampling for performance monitoring
    rationale: Balance between performance insights and Sentry quota usage
metrics:
  duration: 163s
  completed: 2026-01-27
---

# Phase 11 Plan 01: Backend Logging & Monitoring Summary

**One-liner:** JSON-structured logging with correlation IDs and Sentry error tracking for production observability.

## What Was Built

Added production-grade logging and error monitoring infrastructure to the FastAPI backend:

1. **Structured Logging (structlog)**
   - JSON output in production for Railway log aggregation
   - Pretty console output in development
   - Automatic correlation ID injection for request tracking
   - ISO timestamps and stack trace formatting

2. **Sentry Error Monitoring**
   - FastAPI and SQLAlchemy integration
   - Automatic PII scrubbing (auth headers, cookies)
   - 10% trace sampling for performance monitoring
   - Environment and release tagging

3. **Request Tracking**
   - CorrelationIdMiddleware adds unique ID to every request
   - IDs automatically included in all log entries
   - Enables tracing requests across services and async operations

## Tasks Completed

| Task | Name | Commit | Duration |
|------|------|--------|----------|
| 1 | Add dependencies and config | 54d2e29 | ~1min |
| 2 | Create logging and Sentry modules | a609e95 | ~2min |

**Total:** 2/2 tasks, 163s elapsed

## Technical Implementation

### Logging Configuration

**File:** `backend/app/core/logging.py` (69 lines)

```python
def configure_logging():
    """Configure structlog for FastAPI with JSON output in production."""
    # Production: JSON for log aggregation
    # Development: Console renderer for readability
```

**Key features:**
- Environment-based renderer selection
- Correlation ID processor
- ISO timestamps
- Stack trace formatting
- Context variable merging

### Sentry Integration

**File:** `backend/app/core/sentry.py` (52 lines)

```python
def init_sentry():
    """Initialize Sentry SDK with FastAPI integration."""
    # Only initializes if SENTRY_DSN is set
```

**Key features:**
- FastAPI transaction tracking by endpoint
- SQLAlchemy query tracking
- PII scrubbing via before_send hook
- Release versioning (scrollsmith-backend@0.1.0)
- Environment tagging

### Application Integration

**File:** `backend/app/main.py`

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    configure_logging()  # First: set up logging
    init_sentry()        # Second: initialize error tracking
    # ... rest of startup
```

**Middleware order:**
1. CORSMiddleware (existing)
2. CorrelationIdMiddleware (new - added after CORS)

## Dependencies Added

```txt
# Logging & Monitoring (Phase 11)
sentry-sdk>=2.0.0
structlog>=24.0.0
asgi-correlation-id>=4.0.0
```

**Config added:**
```python
SENTRY_DSN: Optional[str] = None  # Set in Railway env vars
```

## Verification Results

### Import Tests
- [x] logging.py imports successfully
- [x] sentry.py imports successfully
- [x] main.py imports all new modules
- [x] No import errors or circular dependencies

### Startup Tests
- [x] Backend loads without errors
- [x] Logging configured (structlog initialized)
- [x] Sentry shows "SENTRY_DSN not configured" (expected without env var)
- [x] CorrelationIdMiddleware registered

### Line Count Requirements
- [x] logging.py: 69 lines (min 40 required)
- [x] sentry.py: 52 lines (min 25 required)

### Key Links Verified
- [x] main.py imports `configure_logging` from logging.py
- [x] main.py imports `init_sentry` from sentry.py
- [x] main.py calls both functions in lifespan startup
- [x] CorrelationIdMiddleware added to app

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

### 1. JSON Logs in Production
**Context:** Railway needs structured logs for aggregation.

**Decision:** Use structlog's JSONRenderer in production, ConsoleRenderer in development.

**Rationale:** JSON enables Railway to parse log fields (timestamp, level, correlation_id) for filtering and search. Console output is more readable for local development.

**Status:** ✓ Implemented in `configure_logging()`

---

### 2. Correlation ID Middleware
**Context:** Need to track requests across async operations and distributed services.

**Decision:** Use `asgi-correlation-id` library with custom processor in structlog.

**Rationale:**
- Automatically generates unique ID per request
- Available in context throughout request lifecycle
- No manual ID passing required
- Works with async FastAPI handlers

**Status:** ✓ Implemented with CorrelationIdMiddleware + add_correlation_id processor

---

### 3. Sentry PII Scrubbing
**Context:** Sentry events could leak auth tokens and sensitive headers.

**Decision:** Implement `before_send` hook that filters authorization, x-api-key, and cookie headers.

**Rationale:**
- Prevents accidental credential leakage to Sentry dashboard
- Better than manually redacting in every error handler
- Runs before events are sent to Sentry servers

**Status:** ✓ Implemented in `scrub_sensitive_data()`

---

### 4. 10% Trace Sampling
**Context:** Sentry charges per transaction, full tracing expensive.

**Decision:** Set `traces_sample_rate=0.1` (10% of requests).

**Rationale:**
- Provides sufficient data for performance insights
- Keeps Sentry quota usage manageable
- Can increase if needed after monitoring costs

**Status:** ✓ Implemented in `init_sentry()`

## Next Phase Readiness

### Ready for Phase 11-02 (Mixpanel Analytics)
- [x] Logging infrastructure in place
- [x] Correlation IDs available for event tracking
- [x] Error monitoring will capture analytics failures

### Production Deployment Requirements
Before deploying to production:

1. **Set SENTRY_DSN in Railway**
   - Create Sentry project at sentry.io
   - Copy DSN to Railway environment variables
   - Verify errors appear in Sentry dashboard

2. **Test Correlation ID Flow**
   - Make API request
   - Check logs for `correlation_id` field
   - Verify same ID appears across all log entries for that request

3. **Test Sentry Integration**
   - Trigger error endpoint (or add test error)
   - Verify error appears in Sentry dashboard
   - Confirm PII scrubbing (auth headers show "[FILTERED]")

### No Blockers
All dependencies installed, imports working, backend starts successfully.

## Usage Examples

### For Developers

**Get a logger in any module:**
```python
from app.core.logging import get_logger

logger = get_logger(__name__)

# In async handler
@router.post("/videos")
async def create_video(request: VideoCreate):
    logger.info("Creating video", video_url=request.url)
    try:
        video = await video_service.create(request)
        logger.info("Video created", video_id=str(video.id))
        return video
    except Exception as e:
        logger.error("Video creation failed", error=str(e))
        raise
```

**Correlation ID automatically included:**
```json
{
  "event": "Creating video",
  "video_url": "https://youtube.com/watch?v=...",
  "correlation_id": "abc123...",
  "timestamp": "2026-01-27T16:05:24Z",
  "level": "info",
  "logger": "app.api.v1.videos"
}
```

**Sentry captures unhandled errors:**
```python
# No need to manually capture - FastAPI integration does it
@router.get("/videos/{video_id}")
async def get_video(video_id: UUID):
    video = await video_service.get(video_id)
    # If this raises, Sentry captures it automatically
    return video
```

### For Operations

**Railway Log Queries:**
```
# Find all errors for a specific request
correlation_id:"abc123"

# Find slow database queries
level:"warning" AND event:"Slow query"

# Find all video creation events
event:"Video created"
```

**Sentry Dashboard:**
- Errors grouped by endpoint
- Stack traces with file/line numbers
- Request context (method, path, query params)
- User context (user_id if available)
- Release tracking (scrollsmith-backend@0.1.0)

## Files Changed

### Created
- `backend/app/core/logging.py` - Structured logging with correlation IDs
- `backend/app/core/sentry.py` - Sentry SDK initialization with PII scrubbing

### Modified
- `backend/requirements.txt` - Added sentry-sdk, structlog, asgi-correlation-id
- `backend/app/core/config.py` - Added SENTRY_DSN optional field
- `backend/app/main.py` - Integrated logging/Sentry in lifespan, added CorrelationIdMiddleware

## Testing Notes

**Local Testing:**
- Logging works without SENTRY_DSN (gracefully skips Sentry init)
- Console output in development is colored and readable
- No errors on import or startup

**Production Testing (after setting SENTRY_DSN):**
1. Deploy to Railway with SENTRY_DSN env var
2. Trigger test error endpoint
3. Verify error appears in Sentry within seconds
4. Check Railway logs for JSON-formatted output
5. Verify correlation IDs present in logs

## Links
- Sentry Python SDK: https://docs.sentry.io/platforms/python/
- structlog: https://www.structlog.org/
- asgi-correlation-id: https://github.com/snok/asgi-correlation-id
