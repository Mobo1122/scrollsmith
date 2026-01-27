# Phase 11: Infrastructure & Polish - Research

**Researched:** 2026-01-27
**Domain:** Production infrastructure, crash reporting, analytics, error handling
**Confidence:** HIGH

## Summary

This phase focuses on production-grade infrastructure: webhook retry logic for RevenueCat, crash reporting for iOS, analytics tracking for key metrics, and comprehensive error handling across both backend and iOS.

The project already uses **tenacity** for API retry logic in the summarization service, providing a solid foundation. For crash reporting, **Sentry** is the recommended choice due to its explicit SwiftUI support (Firebase Crashlytics does not support SwiftUI). For analytics, **Mixpanel** offers a mature Swift SDK with simple integration. Backend structured logging should use **structlog** with JSON output for Railway's log aggregation.

**Primary recommendation:** Use Sentry for both iOS crash reporting AND backend error monitoring (unified platform), Mixpanel for product analytics, and extend the existing tenacity patterns for webhook retry with database-backed dead letter queue.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| sentry-sdk | >=2.0.0 | Backend error monitoring | FastAPI integration, correlates with iOS errors |
| Sentry (iOS) | 8.x | iOS crash reporting + SwiftUI | Only major crash tool with SwiftUI support |
| Mixpanel Swift | 4.x | iOS analytics | Mature SDK, no IDFA required, simple API |
| structlog | >=24.0.0 | Structured JSON logging | Production-grade, FastAPI compatible |
| tenacity | >=8.2.0 | Retry logic (already in use) | Project already uses this for LLM retries |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| asgi-correlation-id | >=4.0.0 | Request correlation IDs | Link logs across request lifecycle |
| python-json-logger | >=2.0.0 | JSON log formatting | Alternative to structlog if simpler needed |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sentry | Firebase Crashlytics | Crashlytics is free but NO SwiftUI support; limited issue management |
| Mixpanel | PostHog | PostHog is open-source with generous free tier but more complex; better for teams wanting self-host |
| Mixpanel | TelemetryDeck | Privacy-focused alternative if GDPR is primary concern |
| structlog | python-json-logger | Simpler but less powerful; structlog has better FastAPI community |

**Installation (Backend):**
```bash
pip install sentry-sdk structlog asgi-correlation-id
```

**Installation (iOS via SPM):**
- Sentry: `https://github.com/getsentry/sentry-cocoa` (8.x)
- Mixpanel: `https://github.com/mixpanel/mixpanel-swift` (v4.x)

## Architecture Patterns

### Recommended Project Structure (Backend additions)

```
backend/app/
├── core/
│   ├── config.py           # Add SENTRY_DSN, MIXPANEL_TOKEN
│   ├── logging.py          # NEW: structlog configuration
│   └── sentry.py           # NEW: Sentry initialization
├── middleware/
│   ├── __init__.py
│   ├── correlation_id.py   # Request correlation IDs
│   └── logging.py          # Request/response logging
├── services/
│   └── webhook_retry.py    # NEW: Webhook retry queue
└── models/
    └── webhook_event.py    # NEW: Webhook dead letter queue
```

### Recommended Project Structure (iOS additions)

```
ios/Scrollsmith/
├── Services/
│   ├── AnalyticsService.swift    # NEW: Centralized analytics
│   ├── CrashReportingService.swift  # NEW: Sentry wrapper
│   └── ErrorHandlingService.swift   # NEW: User-friendly errors
└── ScrollsmithApp.swift          # Add Sentry + Mixpanel init
```

### Pattern 1: Webhook Retry with Dead Letter Queue

**What:** Store failed webhooks in database, retry with exponential backoff, move to dead letter after max attempts.

**When to use:** Any incoming webhook that requires reliable processing (RevenueCat subscriptions).

**Example:**
```python
# Source: https://www.svix.com/resources/webhook-best-practices/retries/
from datetime import datetime, timedelta
from sqlalchemy import select
from tenacity import retry, stop_after_attempt, wait_exponential_jitter

class WebhookEvent(Base):
    __tablename__ = "webhook_events"

    id = Column(UUID, primary_key=True, default=uuid4)
    event_type = Column(String, nullable=False)
    payload = Column(JSON, nullable=False)
    idempotency_key = Column(String, unique=True, index=True)
    status = Column(String, default="pending")  # pending, processing, completed, failed
    attempts = Column(Integer, default=0)
    next_retry_at = Column(DateTime, nullable=True)
    error_message = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

async def process_webhook_with_retry(event_id: UUID, db: AsyncSession):
    """Process webhook with idempotency and retry tracking."""
    event = await db.get(WebhookEvent, event_id)

    # Idempotency check - already completed
    if event.status == "completed":
        return {"status": "already_processed"}

    event.status = "processing"
    event.attempts += 1
    await db.commit()

    try:
        # Actual processing logic
        await handle_subscription_event(event.payload)
        event.status = "completed"
    except Exception as e:
        if event.attempts >= 5:
            event.status = "failed"  # Dead letter
            event.error_message = str(e)
        else:
            # Schedule retry with exponential backoff: 5, 10, 20, 40, 80 min
            delay_minutes = 5 * (2 ** (event.attempts - 1))
            event.status = "pending"
            event.next_retry_at = datetime.utcnow() + timedelta(minutes=delay_minutes)

    await db.commit()
```

### Pattern 2: Centralized iOS Analytics Service

**What:** Single entry point for all analytics events with consistent event naming.

**When to use:** All user interactions that need tracking.

**Example:**
```swift
// Source: https://mixpanel.com/blog/how-to-add-analytics-event-tracking-in-swiftui-the-elegant-way/
import Mixpanel

actor AnalyticsService {
    static let shared = AnalyticsService()

    private init() {
        Mixpanel.initialize(token: Configuration.mixpanelToken, trackAutomaticEvents: false)
    }

    // MARK: - Key Events per Success Criteria

    func trackVideoView(videoId: UUID) {
        Mixpanel.mainInstance().track(event: "video_viewed", properties: [
            "video_id": videoId.uuidString
        ])
    }

    func trackHabitCompletion(habitId: UUID, streakLength: Int) {
        Mixpanel.mainInstance().track(event: "habit_completed", properties: [
            "habit_id": habitId.uuidString,
            "streak_length": streakLength
        ])
    }

    func trackProConversion(source: String) {
        Mixpanel.mainInstance().track(event: "pro_conversion", properties: [
            "source": source  // "paywall", "habit_limit", "summary_format"
        ])
    }

    // User identification for retention tracking
    func identifyUser(userId: UUID, isPro: Bool) {
        Mixpanel.mainInstance().identify(distinctId: userId.uuidString)
        Mixpanel.mainInstance().people.set(properties: [
            "is_pro": isPro,
            "platform": "ios"
        ])
    }
}
```

### Pattern 3: User-Friendly Error Display with Recovery

**What:** Convert API errors to localized, actionable messages with retry options.

**When to use:** Any API call that can fail.

**Example:**
```swift
// Source: https://holyswift.app/best-way-to-present-error-in-swiftui/
enum AppError: LocalizedError {
    case network(underlying: Error)
    case serverError(statusCode: Int)
    case noInternet
    case unauthorized
    case proRequired
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .network:
            return "Unable to connect to server"
        case .serverError(let code):
            return "Something went wrong (Error \(code))"
        case .noInternet:
            return "No internet connection"
        case .unauthorized:
            return "Please log in again"
        case .proRequired:
            return "This feature requires Pro"
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .network, .serverError, .noInternet:
            return "Please try again"
        case .unauthorized:
            return "Tap to log in"
        case .proRequired:
            return "Upgrade to Pro to unlock"
        case .unknown:
            return nil
        }
    }

    var isRetryable: Bool {
        switch self {
        case .network, .serverError, .noInternet:
            return true
        default:
            return false
        }
    }
}

// ViewModifier for consistent error alerts
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?
    var retryAction: (() -> Void)?

    func body(content: Content) -> some View {
        content.alert(
            "Error",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            ),
            presenting: error
        ) { error in
            if error.isRetryable, let retry = retryAction {
                Button("Retry", action: retry)
            }
            Button("OK", role: .cancel) {}
        } message: { error in
            VStack {
                Text(error.localizedDescription)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                }
            }
        }
    }
}

extension View {
    func errorAlert(_ error: Binding<AppError?>, retryAction: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, retryAction: retryAction))
    }
}
```

### Pattern 4: Structured Logging with Correlation IDs

**What:** JSON-formatted logs with request correlation for debugging.

**When to use:** All backend logging.

**Example:**
```python
# Source: https://gist.github.com/nymous/f138c7f06062b7c43c060bf03759c29e
import structlog
import logging
from asgi_correlation_id import CorrelationIdMiddleware
from asgi_correlation_id.context import correlation_id

def configure_logging():
    """Configure structlog for FastAPI with JSON output in production."""

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            # Add correlation ID to all logs
            add_correlation_id,
            # JSON in production, pretty in dev
            structlog.processors.JSONRenderer()
            if settings.ENVIRONMENT == "production"
            else structlog.dev.ConsoleRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
    )

def add_correlation_id(logger, method_name, event_dict):
    """Add request correlation ID to log entries."""
    request_id = correlation_id.get()
    if request_id:
        event_dict["correlation_id"] = request_id
    return event_dict

# Usage in services
logger = structlog.get_logger(__name__)

async def process_webhook(event: dict):
    logger.info("processing_webhook",
        event_type=event.get("type"),
        user_id=event.get("app_user_id")
    )
```

### Anti-Patterns to Avoid

- **Silent failures:** Never catch exceptions without logging or user notification
- **Generic error messages:** "Something went wrong" with no actionable info
- **Retry without backoff:** Will overwhelm services during outages
- **Retry on 4xx errors:** Only retry transient failures (5xx, timeouts, network)
- **No idempotency:** Webhook handlers must handle duplicate delivery
- **Blocking webhook response:** Process async, respond 200 immediately

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Crash symbolication | Custom dSYM processing | Sentry/Crashlytics | Symbolication is complex; need version tracking |
| Retry with jitter | Custom sleep + random | tenacity `wait_exponential_jitter` | Edge cases in backoff calculation |
| Log correlation | Manual request ID passing | asgi-correlation-id | Context vars handle async correctly |
| Analytics deduplication | Custom event tracking | Mixpanel's built-in | Race conditions, session handling |
| Error grouping | Manual exception categorization | Sentry's auto-grouping | ML-based grouping catches variations |

**Key insight:** Production infrastructure has many subtle edge cases (timezone handling in analytics, proper async context in logging, dSYM upload timing). Use battle-tested libraries.

## Common Pitfalls

### Pitfall 1: Webhook Handler Timeout

**What goes wrong:** RevenueCat has 60-second timeout; processing takes too long, webhook retries pile up.
**Why it happens:** Doing database writes, external API calls in the webhook handler.
**How to avoid:** Acknowledge immediately (200), process asynchronously.
**Warning signs:** Duplicate subscription events, RevenueCat dashboard showing retries.

### Pitfall 2: Missing Idempotency Keys

**What goes wrong:** Same webhook processed multiple times, user gets double credits or notifications.
**Why it happens:** RevenueCat guarantees "at least once" delivery, not "exactly once."
**How to avoid:** Store `event.id` in database before processing, check before each attempt.
**Warning signs:** Duplicate log entries, users complaining about duplicate actions.

### Pitfall 3: Crash Reports Not Uploading (iOS)

**What goes wrong:** Crashes happen but don't appear in Sentry dashboard.
**Why it happens:** Xcode debugger attached prevents crash report transmission.
**How to avoid:** Test crashes by running app without debugger (Archive build or disconnect).
**Warning signs:** Zero crashes in production dashboard despite user reports.

### Pitfall 4: Missing dSYM Files

**What goes wrong:** Crash reports show unsymbolicated stack traces (memory addresses only).
**Why it happens:** dSYM files not uploaded to Sentry after each build.
**How to avoid:** Add Sentry's dSYM upload build phase; verify in Sentry project settings.
**Warning signs:** Stack traces show `0x...` addresses instead of function names.

### Pitfall 5: Logging Sensitive Data

**What goes wrong:** PII (emails, tokens) end up in logs visible to all developers.
**Why it happens:** Logging full request/response bodies without filtering.
**How to avoid:** Explicitly list logged fields; never log authorization headers or passwords.
**Warning signs:** Security audit flags, GDPR concerns.

### Pitfall 6: Analytics Without User Consent (iOS 17+)

**What goes wrong:** App rejected from App Store or legal issues.
**Why it happens:** Tracking before ATT consent or without proper disclosure.
**How to avoid:** Mixpanel doesn't use IDFA (no ATT needed), but still need privacy policy.
**Warning signs:** App Store rejection citing privacy violations.

## Code Examples

### Sentry iOS Initialization

```swift
// Source: https://docs.sentry.io/platforms/apple/guides/ios/
import Sentry

@main
struct ScrollsmithApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = Configuration.sentryDSN
            options.debug = Configuration.isDebug
            options.tracesSampleRate = 0.2  // 20% of transactions
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            // Don't send PII by default
            options.sendDefaultPii = false
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Sentry FastAPI Initialization

```python
# Source: https://docs.sentry.io/platforms/python/integrations/fastapi/
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

def init_sentry():
    if settings.SENTRY_DSN:
        sentry_sdk.init(
            dsn=settings.SENTRY_DSN,
            environment=settings.ENVIRONMENT,
            traces_sample_rate=0.1,  # 10% of requests
            integrations=[
                FastApiIntegration(transaction_style="endpoint"),
                SqlalchemyIntegration(),
            ],
            # Scrub sensitive data
            before_send=scrub_sensitive_data,
        )

def scrub_sensitive_data(event, hint):
    """Remove sensitive data from Sentry events."""
    if "request" in event and "headers" in event["request"]:
        headers = event["request"]["headers"]
        if "authorization" in headers:
            headers["authorization"] = "[FILTERED]"
    return event
```

### LLM Error Handling with Fallback

```python
# Source: Existing summarization.py pattern extended
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential_jitter,
    retry_if_exception_type,
    before_sleep_log,
)
import structlog

logger = structlog.get_logger(__name__)

class LLMService:
    @retry(
        retry=retry_if_exception_type((RateLimitError, APIStatusError)),
        wait=wait_exponential_jitter(initial=1, max=60, jitter=2),
        stop=stop_after_attempt(5),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )
    async def _call_with_retry(self, **kwargs):
        """Call LLM API with retry, logging, and timeout."""
        try:
            async with asyncio.timeout(30):  # 30 second timeout
                return await self.client.messages.create(**kwargs)
        except asyncio.TimeoutError:
            logger.warning("llm_timeout", model=kwargs.get("model"))
            raise APIStatusError("Timeout", response=None, body=None)

    async def generate_with_fallback(self, transcript: str) -> str:
        """Generate summary with graceful degradation."""
        try:
            return await self._call_with_retry(
                model="claude-sonnet-4-5-20250514",
                # ... params
            )
        except Exception as e:
            logger.error("llm_failed", error=str(e))
            # Fallback: return structured error message
            return {
                "error": True,
                "message": "Summary generation temporarily unavailable",
                "retry_after": 60
            }
```

### Mixpanel SwiftUI View Tracking

```swift
// Source: https://medium.com/@alinekborges/tracking-screen-views-in-swiftui-with-a-custom-viewmodifier-7a52e8f00f89
import Mixpanel

struct ScreenTrackingModifier: ViewModifier {
    let screenName: String

    func body(content: Content) -> some View {
        content.onAppear {
            Mixpanel.mainInstance().track(event: "screen_viewed", properties: [
                "screen_name": screenName
            ])
        }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(ScreenTrackingModifier(screenName: name))
    }
}

// Usage
struct VideoGridView: View {
    var body: some View {
        // ... content
    }
    .trackScreen("video_grid")
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Firebase Crashlytics only | Sentry with SwiftUI support | 2024 | Required for SwiftUI apps |
| print() debugging | Structured JSON logging | Industry standard | Enables log aggregation, search |
| Manual retry loops | tenacity/backoff libraries | Python 3.6+ | Correct jitter, cleaner code |
| IDFA-based analytics | Privacy-first analytics (Mixpanel) | iOS 14.5+ (2021) | No ATT prompt required |

**Deprecated/outdated:**
- Firebase Crashlytics for SwiftUI: Does not capture SwiftUI-specific issues
- Amplitude for indie apps: Pricing not competitive with Mixpanel free tier
- Custom logging formatters: structlog handles edge cases better

## Open Questions

1. **PostHog vs Mixpanel final decision**
   - What we know: Both are solid options; Mixpanel is more mature for iOS
   - What's unclear: PostHog's iOS SDK maturity, session replay quality
   - Recommendation: Start with Mixpanel (simpler), evaluate PostHog later if feature flags needed

2. **Dead letter queue storage**
   - What we know: Database-backed is simplest for Railway
   - What's unclear: Whether Redis/ARQ is worth the infrastructure complexity
   - Recommendation: Database table for v1, add Redis if volume warrants

3. **Retention metric definition**
   - What we know: Success criteria mentions "retention" tracking
   - What's unclear: D1/D7/D30 retention? Definition of "active user"?
   - Recommendation: Track daily active (any API call), calculate D1/D7/D30 cohorts in Mixpanel

## Sources

### Primary (HIGH confidence)
- Sentry iOS SDK docs - https://docs.sentry.io/platforms/apple/guides/ios/
- Sentry FastAPI integration - https://docs.sentry.io/platforms/python/integrations/fastapi/
- tenacity documentation - https://tenacity.readthedocs.io/en/latest/
- RevenueCat webhook docs - https://www.revenuecat.com/docs/integrations/webhooks
- Mixpanel Swift SDK - https://docs.mixpanel.com/docs/tracking-methods/sdks/swift

### Secondary (MEDIUM confidence)
- structlog documentation - https://www.structlog.org/en/stable/
- Sentry vs Crashlytics comparison - https://sentry.io/from/crashlytics/ (verified with multiple sources)
- FastAPI structured logging patterns - https://gist.github.com/nymous/f138c7f06062b7c43c060bf03759c29e

### Tertiary (LOW confidence)
- PostHog vs Mixpanel comparisons - WebSearch only, evaluate both before final decision
- ARQ vs Celery for webhook processing - Community opinions, validate with testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official docs consulted for all recommendations
- Architecture: HIGH - Patterns verified from official sources and existing codebase
- Pitfalls: MEDIUM - Mix of official docs and community experience

**Research date:** 2026-01-27
**Valid until:** 60 days (infrastructure libraries are stable)
