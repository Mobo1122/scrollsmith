# Phase 8: Subscription System - Research

**Researched:** 2026-01-24
**Domain:** In-app purchases, subscription management, RevenueCat integration
**Confidence:** HIGH

## Summary

This research covers implementing a subscription system with RevenueCat for iOS and FastAPI backend. The core requirements are: free tier with 10 videos/month usage limit, Pro tier with unlimited access, RevenueCat SDK integration, backend webhook handling, and paywall UI.

RevenueCat SDK 5.x with StoreKit 2 is the standard approach for iOS 17+ subscription apps. The SDK handles all StoreKit complexity and provides a unified backend for subscription status. For backend integration, RevenueCat webhooks notify of subscription changes, while the REST API v1 (`/v1/subscribers/{app_user_id}`) provides on-demand verification.

**Primary recommendation:** Use RevenueCat SDK 5.x with StoreKit 2 (default), custom App User IDs tied to backend user IDs, and a webhook-triggered sync pattern for backend subscription status.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| RevenueCat SDK | 5.x | iOS subscription management | StoreKit 2 support, cross-platform, handles receipts |
| RevenueCatUI | 5.x | Paywall components | Pre-built PaywallView, remote configuration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| httpx | 0.27+ | Async HTTP client (Python) | Backend REST API calls to RevenueCat |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| RevenueCat | StoreKit 2 directly | More control but massive complexity (receipt validation, server notifications, grace periods) |
| RevenueCatUI | Custom paywall | Full design control but must handle purchase flow, restore, eligibility manually |

**Installation (iOS):**
```swift
// Swift Package Manager
// URL: https://github.com/RevenueCat/purchases-ios-spm.git
// Version: Up to next major from 5.0.0
// Products: RevenueCat, RevenueCatUI
```

**Installation (Backend):**
```bash
pip install httpx
```

## Architecture Patterns

### Recommended Project Structure

**iOS:**
```
ios/Scrollsmith/
├── Services/
│   └── SubscriptionService.swift     # RevenueCat wrapper, entitlement checks
├── ViewModels/
│   └── SubscriptionViewModel.swift   # Usage tracking, tier state
├── Views/
│   └── Subscription/
│       ├── PaywallView.swift         # Custom paywall (wraps RevenueCatUI)
│       ├── UsagePillView.swift       # Header usage indicator
│       └── UsageDetailSheet.swift    # Full usage details
└── Models/
    └── UsageState.swift              # Usage tracking model
```

**Backend:**
```
backend/app/
├── api/v1/endpoints/
│   └── subscriptions.py              # Webhook endpoint, usage API
├── models/
│   └── user.py                       # Add usage tracking fields
├── schemas/
│   └── subscription.py               # Webhook payload, usage response
└── services/
    └── revenuecat.py                 # RevenueCat API client
```

### Pattern 1: Custom App User ID Strategy

**What:** Use backend user UUID as RevenueCat App User ID for seamless cross-platform subscription tracking.

**When to use:** Apps with user authentication (like Scrollsmith with Apple Sign In).

**Example:**
```swift
// After successful login, configure RevenueCat with backend user ID
func configureRevenueCat(userId: UUID) {
    Purchases.logLevel = .debug
    Purchases.configure(
        withAPIKey: "appl_YOUR_PUBLIC_KEY",
        appUserID: userId.uuidString.lowercased()
    )
}

// On logout - do NOT call logOut() to avoid anonymous ID creation
// Just reconfigure on next login with new user ID
```

**Critical:** Never call `configure()` without a user ID if you want to avoid anonymous IDs. Wait until authentication completes.

### Pattern 2: Webhook-Triggered Sync

**What:** Use webhooks as triggers to sync subscription status from RevenueCat API, not as the source of truth.

**When to use:** Always. This pattern handles edge cases and simplifies webhook handling.

**Example:**
```python
# Backend webhook handler
@router.post("/webhooks/revenuecat")
async def handle_revenuecat_webhook(
    request: Request,
    authorization: str = Header(...),
    db: AsyncSession = Depends(get_db),
):
    # 1. Verify authorization header
    if authorization != f"Bearer {settings.REVENUECAT_WEBHOOK_SECRET}":
        raise HTTPException(status_code=401)

    # 2. Parse event to get app_user_id
    payload = await request.json()
    app_user_id = payload.get("app_user_id")

    # 3. Fetch fresh subscription status from RevenueCat API
    subscription_info = await revenuecat_service.get_subscriber(app_user_id)

    # 4. Update user in database
    await update_user_subscription(db, app_user_id, subscription_info)

    return {"status": "ok"}
```

### Pattern 3: Entitlement-Based Access Control

**What:** Check entitlements (not products) for feature access. Entitlements are configured in RevenueCat dashboard and can map multiple products to one entitlement.

**When to use:** Always for feature gating.

**Example:**
```swift
// iOS - checking Pro access
func checkProAccess() async -> Bool {
    do {
        let customerInfo = try await Purchases.shared.customerInfo()
        return customerInfo.entitlements["pro"]?.isActive == true
    } catch {
        return false
    }
}

// Backend - checking Pro access via API
async def check_pro_access(app_user_id: str) -> bool:
    response = await httpx_client.get(
        f"https://api.revenuecat.com/v1/subscribers/{app_user_id}",
        headers={"Authorization": f"Bearer {settings.REVENUECAT_API_KEY}"}
    )
    data = response.json()
    entitlements = data.get("subscriber", {}).get("entitlements", {})
    pro = entitlements.get("pro", {})

    if not pro:
        return False

    expires_date = pro.get("expires_date")
    if expires_date:
        return datetime.fromisoformat(expires_date.replace("Z", "+00:00")) > datetime.now(timezone.utc)
    return True
```

### Pattern 4: Usage Tracking with Monthly Reset

**What:** Track video count per billing period with reset on 1st of month.

**When to use:** Free tier usage limits.

**Example:**
```python
# Backend User model additions
class User(Base):
    # ... existing fields ...

    # Usage tracking
    videos_this_month: Mapped[int] = mapped_column(Integer, default=0)
    usage_reset_date: Mapped[date] = mapped_column(Date, nullable=True)

# Usage check function
async def check_and_increment_usage(db: AsyncSession, user: User) -> tuple[bool, int]:
    """Returns (can_create_video, current_usage)"""
    today = date.today()

    # Reset if new month
    if user.usage_reset_date is None or user.usage_reset_date.month != today.month:
        user.videos_this_month = 0
        user.usage_reset_date = today.replace(day=1)

    # Pro users: unlimited
    if user.subscription_tier == "pro":
        user.videos_this_month += 1
        await db.commit()
        return (True, user.videos_this_month)

    # Free users: check limit
    if user.videos_this_month >= 10:
        return (False, user.videos_this_month)

    user.videos_this_month += 1
    await db.commit()
    return (True, user.videos_this_month)
```

### Anti-Patterns to Avoid

- **Calling configure() multiple times:** Only call once at app launch after auth.
- **Using anonymous IDs with authentication:** Always pass custom App User ID.
- **Trusting client-side entitlement checks:** Always verify on backend for sensitive operations.
- **Processing webhook payload directly:** Use webhook as trigger, fetch fresh data from API.
- **Hardcoding product IDs in app:** Use entitlements and offerings configured in dashboard.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Receipt validation | Custom validation logic | RevenueCat SDK | Apple receipt format is complex, changes frequently |
| Subscription status sync | Direct StoreKit listeners | RevenueCat webhooks + API | Grace periods, family sharing, refunds handled |
| Paywall UI | Custom purchase buttons | RevenueCatUI PaywallView | Handles eligibility, restore, loading states |
| Trial eligibility | Track locally | RevenueCat `checkTrialOrIntroDiscountEligibility` | Considers all Apple accounts, prior purchases |
| Cross-platform status | Separate tracking | RevenueCat single source of truth | Handles transfers, restores automatically |

**Key insight:** StoreKit 2 is simpler than StoreKit 1, but RevenueCat still saves weeks of edge case handling (billing retry, grace periods, refunds, family sharing, receipt fraud).

## Common Pitfalls

### Pitfall 1: Calling configure() Before Authentication
**What goes wrong:** Anonymous user ID created, then login creates new ID, subscription lost.
**Why it happens:** Natural to configure SDK in AppDelegate/App init.
**How to avoid:** Wait for authentication, configure with backend user ID.
**Warning signs:** Users report lost purchases after login/logout.

### Pitfall 2: Relying on Client-Side Entitlement Checks Only
**What goes wrong:** Users bypass limits with modified apps or API manipulation.
**Why it happens:** Faster to just check locally.
**How to avoid:** Server-side verification for all tier-gated features (already done in Phase 5).
**Warning signs:** Unrealistic usage patterns in analytics.

### Pitfall 3: Not Handling Webhook Retries
**What goes wrong:** Duplicate subscription grants or inconsistent state.
**Why it happens:** RevenueCat retries failed webhooks with same event ID.
**How to avoid:** Store event IDs, check for duplicates, use idempotent operations.
**Warning signs:** Multiple database entries for same subscription event.

### Pitfall 4: TestFlight with StoreKit Configuration File
**What goes wrong:** Purchases work in Xcode but fail in TestFlight.
**Why it happens:** StoreKit Configuration is for simulator only, TestFlight uses sandbox.
**How to avoid:** Set StoreKit Configuration to "None" for TestFlight builds.
**Warning signs:** "Could not connect to the App Store" errors in TestFlight.

### Pitfall 5: Not Caching Subscription Status
**What goes wrong:** API rate limits hit, slow app performance.
**Why it happens:** Checking RevenueCat API on every screen.
**How to avoid:** Cache subscription status for 5 minutes (SDK does this automatically).
**Warning signs:** Slow feature access, high API usage.

### Pitfall 6: Forgetting Billing Grace Period
**What goes wrong:** Users lose access during payment retry period.
**Why it happens:** Only checking `expires_date`, ignoring `grace_period_expires_date`.
**How to avoid:** Check both dates, grant access during grace period.
**Warning signs:** User complaints about "unfair" access loss.

## Code Examples

Verified patterns from official sources:

### RevenueCat SDK Configuration (iOS)
```swift
// Source: RevenueCat docs - Configuring the SDK
import RevenueCat
import RevenueCatUI

@main
struct ScrollsmithApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        // Enable debug logging in development
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .onAppear {
                    // Configure after auth state is known
                    if let userId = authViewModel.currentUser?.id {
                        configureRevenueCat(userId: userId)
                    }
                }
                .onChange(of: authViewModel.currentUser) { _, newUser in
                    if let userId = newUser?.id {
                        configureRevenueCat(userId: userId)
                    }
                }
        }
    }

    private func configureRevenueCat(userId: UUID) {
        Purchases.configure(
            withAPIKey: "appl_YOUR_PUBLIC_API_KEY",
            appUserID: userId.uuidString.lowercased()
        )
    }
}
```

### Displaying Paywall with Entitlement Check (iOS)
```swift
// Source: RevenueCat docs - Displaying Paywalls
import SwiftUI
import RevenueCat
import RevenueCatUI

struct ProtectedFeatureView: View {
    var body: some View {
        ContentView()
            .presentPaywallIfNeeded(
                requiredEntitlementIdentifier: "pro",
                purchaseCompleted: { customerInfo in
                    print("Purchase completed: \(customerInfo.entitlements)")
                },
                restoreCompleted: { customerInfo in
                    print("Purchases restored: \(customerInfo.entitlements)")
                }
            )
    }
}

// Manual presentation for soft-block pattern
struct SummaryDisplayView: View {
    @State private var showPaywall = false
    @State private var isPro = false

    var body: some View {
        VStack {
            // Content here
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            await checkSubscriptionStatus()
        }
    }

    private func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPro = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            isPro = false
        }
    }
}
```

### Backend Webhook Handler (FastAPI)
```python
# Source: RevenueCat docs - Webhooks
from fastapi import APIRouter, Request, Header, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone
import httpx

router = APIRouter()

REVENUECAT_EVENTS = {
    "INITIAL_PURCHASE": "initial_purchase",
    "RENEWAL": "renewal",
    "CANCELLATION": "cancellation",
    "EXPIRATION": "expiration",
    "BILLING_ISSUE": "billing_issue",
    "PRODUCT_CHANGE": "product_change",
}

@router.post("/webhooks/revenuecat")
async def handle_revenuecat_webhook(
    request: Request,
    authorization: str = Header(None),
    db: AsyncSession = Depends(get_db),
):
    """Handle RevenueCat webhook events.

    Pattern: Use webhook as trigger, fetch fresh data from API.
    """
    # Verify authorization header
    expected = f"Bearer {settings.REVENUECAT_WEBHOOK_SECRET}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")

    payload = await request.json()
    event_type = payload.get("type")
    event_id = payload.get("id")
    app_user_id = payload.get("app_user_id")

    # Idempotency check (optional but recommended)
    if await event_already_processed(db, event_id):
        return {"status": "already_processed"}

    # Fetch fresh subscriber data from RevenueCat API
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://api.revenuecat.com/v1/subscribers/{app_user_id}",
            headers={
                "Authorization": f"Bearer {settings.REVENUECAT_API_KEY}",
                "Content-Type": "application/json",
            }
        )

    if response.status_code != 200:
        # Log error but return 200 to prevent retries for permanent failures
        logger.error(f"RevenueCat API error: {response.status_code}")
        return {"status": "api_error"}

    subscriber_data = response.json()

    # Update user subscription status
    await sync_subscription_status(db, app_user_id, subscriber_data)

    # Mark event as processed
    await mark_event_processed(db, event_id)

    return {"status": "ok"}


async def sync_subscription_status(
    db: AsyncSession,
    app_user_id: str,
    subscriber_data: dict
):
    """Sync subscription status from RevenueCat data to User model."""
    from app.models import User
    from sqlalchemy import select

    # Parse UUID from app_user_id
    try:
        user_id = UUID(app_user_id)
    except ValueError:
        logger.warning(f"Invalid app_user_id format: {app_user_id}")
        return

    result = await db.execute(
        select(User).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()

    if not user:
        logger.warning(f"User not found for app_user_id: {app_user_id}")
        return

    # Check entitlements
    entitlements = subscriber_data.get("subscriber", {}).get("entitlements", {})
    pro_entitlement = entitlements.get("pro", {})

    if pro_entitlement:
        expires_date_str = pro_entitlement.get("expires_date")
        grace_period_str = pro_entitlement.get("grace_period_expires_date")

        # Check if active (considering grace period)
        now = datetime.now(timezone.utc)
        is_active = False

        if expires_date_str:
            expires_date = datetime.fromisoformat(expires_date_str.replace("Z", "+00:00"))
            is_active = expires_date > now

        if not is_active and grace_period_str:
            grace_date = datetime.fromisoformat(grace_period_str.replace("Z", "+00:00"))
            is_active = grace_date > now

        user.subscription_tier = "pro" if is_active else "free"
    else:
        user.subscription_tier = "free"

    await db.commit()
```

### Usage Tracking Endpoint (FastAPI)
```python
# Backend API for iOS to fetch usage status
from pydantic import BaseModel
from datetime import date

class UsageResponse(BaseModel):
    videos_used: int
    videos_limit: int  # -1 for unlimited
    reset_date: date
    is_pro: bool
    can_create_video: bool

@router.get("/usage", response_model=UsageResponse)
async def get_usage(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get current usage status for the user."""
    today = date.today()

    # Reset if new month
    if current_user.usage_reset_date is None or \
       current_user.usage_reset_date.month != today.month:
        current_user.videos_this_month = 0
        current_user.usage_reset_date = today.replace(day=1)
        await db.commit()
        await db.refresh(current_user)

    is_pro = current_user.subscription_tier == "pro"

    return UsageResponse(
        videos_used=current_user.videos_this_month,
        videos_limit=-1 if is_pro else 10,
        reset_date=current_user.usage_reset_date or today.replace(day=1),
        is_pro=is_pro,
        can_create_video=is_pro or current_user.videos_this_month < 10,
    )
```

### Restore Purchases (iOS)
```swift
// Source: RevenueCat docs
func restorePurchases() async throws -> Bool {
    let customerInfo = try await Purchases.shared.restorePurchases()
    return customerInfo.entitlements["pro"]?.isActive == true
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| StoreKit 1 receipts | StoreKit 2 transactions | iOS 15+ / SDK 5.0 (2024) | No more "missing receipt" errors |
| Observer Mode | PurchasesAreCompletedBy | SDK 5.0 | Clearer ownership model |
| Anonymous-first IDs | Custom App User IDs | Best practice | Better cross-platform tracking |
| Client-only entitlements | Server-side verification | Always | Security requirement |

**Deprecated/outdated:**
- StoreKit 1 APIs: Still work but being phased out by Apple
- RevenueCat SDK 4.x: Missing StoreKit 2 default, some API changes
- Observer Mode terminology: Now "PurchasesAreCompletedBy"

## Testing Strategy

### Development (Xcode + StoreKit Configuration)
1. Create StoreKit Configuration file with test products
2. Use Xcode scheme to select configuration file
3. Test purchase flows locally (no App Store Connect setup needed)
4. **Limitation:** Cannot test restore across devices

### Sandbox (App Store Connect)
1. Create Sandbox test accounts in App Store Connect
2. Set StoreKit Configuration to "None" in scheme
3. Sign in with sandbox account on device (Settings > Developer > Sandbox Account on iOS 18+)
4. Test real purchase flows against Apple sandbox

### TestFlight (Production Sandbox)
1. Upload build to TestFlight
2. **Critical:** Remove StoreKit Configuration file from scheme
3. Testers use their sandbox accounts automatically
4. **Note:** As of December 2024, renewals occur every 24 hours (not minutes)

### Production Checklist
- [ ] Replace test API key with production key
- [ ] Verify products in App Store Connect are "Ready to Submit" or "Approved"
- [ ] Test purchase flow with sandbox account
- [ ] Verify webhook endpoint receives events
- [ ] Confirm subscription status syncs to backend

## Key Decisions for Planning

1. **RevenueCat Entitlement ID:** Use "pro" as the single entitlement for Pro tier
2. **Product IDs:** Create in App Store Connect (e.g., `com.scrollsmith.pro.monthly`, `com.scrollsmith.pro.annual`)
3. **Offering ID:** Use "default" offering configured in RevenueCat dashboard
4. **Webhook Secret:** Generate secure random string, store in Railway environment
5. **Usage Reset:** 1st of month (UTC), not billing anniversary (simpler, matches user mental model)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| App Store review rejection | HIGH | Use Apple's standard IAP patterns, no external payment links |
| Webhook delivery failure | MEDIUM | Implement retry handling, manual sync endpoint |
| User loses subscription on reinstall | MEDIUM | Test restore flow thoroughly, clear restore button in UI |
| StoreKit sandbox instability | LOW | Accept metadata inaccuracies in testing, verify in production |
| RevenueCat API outage | LOW | SDK caches entitlements, graceful degradation |

## Open Questions

Things that couldn't be fully resolved:

1. **Exact pricing amounts**
   - What we know: Monthly + Annual plans with 3-day trial, annual at ~2 months discount
   - What's unclear: Specific USD amounts
   - Recommendation: Configure in App Store Connect during implementation (CONTEXT.md says "Claude's Discretion")

2. **RevenueCat Pro plan requirement for webhooks**
   - What we know: Webhooks require RevenueCat Pro plan
   - What's unclear: Current plan status
   - Recommendation: Verify account plan, upgrade if needed

## Sources

### Primary (HIGH confidence)
- [RevenueCat iOS SDK Installation](https://www.revenuecat.com/docs/getting-started/installation/ios)
- [RevenueCat Configuring SDK](https://www.revenuecat.com/docs/getting-started/configuring-sdk)
- [RevenueCat Displaying Paywalls](https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls)
- [RevenueCat Webhooks](https://www.revenuecat.com/docs/integrations/webhooks)
- [RevenueCat Event Types and Fields](https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields)
- [RevenueCat Customer Info](https://www.revenuecat.com/docs/customers/customer-info)
- [RevenueCat Identifying Customers](https://www.revenuecat.com/docs/customers/identifying-customers)
- [RevenueCat Apple Sandbox Testing](https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store)

### Secondary (MEDIUM confidence)
- [RevenueCat SDK 5.0 Blog Post](https://www.revenuecat.com/blog/engineering/revenuecat-sdk-5-0-the-storekit-2-update/)
- [iOS Subscription Testing Ultimate Guide](https://www.revenuecat.com/blog/engineering/the-ultimate-guide-to-subscription-testing-on-ios/)
- [RevenueCat Community - Backend Verification](https://community.revenuecat.com/general-questions-7/how-to-verify-subscription-status-on-my-express-backend-4535)

### Tertiary (LOW confidence)
- WebSearch results on paywall conversion patterns (verify specific claims)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official RevenueCat documentation
- Architecture: HIGH - Official patterns and community best practices
- Pitfalls: HIGH - Well-documented in RevenueCat community and testing guides
- Testing: HIGH - Official documentation with recent updates (Dec 2024)

**Research date:** 2026-01-24
**Valid until:** 2026-02-24 (RevenueCat SDK stable, recommend re-checking before implementation)
