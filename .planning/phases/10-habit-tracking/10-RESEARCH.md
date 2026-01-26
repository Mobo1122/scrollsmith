# Phase 10: Habit Tracking - Research

**Researched:** 2026-01-26
**Domain:** iOS local notifications, streak algorithms, habit completion tracking, ADHD-friendly UX
**Confidence:** HIGH

## Summary

Phase 10 implements the habit tracking system including reminders via local notifications, habit completions, streak calculations with 1-day forgiveness, visualization, and habit editing/deletion. The iOS app uses `UNUserNotificationCenter` for scheduling repeating local notifications with actionable "Mark Complete" buttons. The backend tracks completions in a new `habit_completions` table and calculates streaks using PostgreSQL window functions.

The existing codebase has the `Habit` model on both backend and iOS, plus the habits API with extraction/creation/listing/deletion. This phase adds: reminder time storage, completion recording, streak calculation with timezone-aware logic, notification scheduling, notification actions, and a minimalist streak visualization (GitHub-style contribution graph or simple calendar heatmap).

**Primary recommendation:** Use local notifications (not push) for habit reminders since they work offline and are simpler. Store completions with user timezone for accurate streak calculation. Implement 1-day forgiveness in the streak algorithm by allowing a single gap day. Use SwiftUI-ContributionChart or Swift Charts for ADHD-friendly minimal visualization.

## Standard Stack

The established libraries/tools for this domain:

### Core (Already in Project / System Frameworks)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| UNUserNotificationCenter | iOS 17+ | Local notification scheduling | Apple's official notification framework |
| UNNotificationAction | iOS 17+ | Actionable notification buttons | Built-in support for "Mark Complete" |
| Swift Charts | iOS 16+ | Streak visualization | Apple native, minimal code, accessible |
| SwiftData | iOS 17+ | Local habit/completion storage | Already used for habits |
| PostgreSQL window functions | 15+ | Streak calculation | Efficient consecutive day grouping |

### Supporting (No New Dependencies Needed)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DateComponents | Foundation | Scheduling repeating notifications | Daily/weekly calendar triggers |
| Calendar | Foundation | Timezone-aware date math | Streak day boundaries |
| TimeZone | Foundation | User timezone handling | Store with completions |

### Optional Third-Party (Consider Only If Native Insufficient)
| Library | Purpose | Tradeoff |
|---------|---------|----------|
| SwiftUI-ContributionChart | GitHub-style heatmap | Simple API, but adds dependency |
| FSCalendar (UIKit) | Full calendar view | Powerful but requires UIViewRepresentable wrapper |

**Installation:**
No new dependencies required. All functionality provided by system frameworks.

## Architecture Patterns

### Recommended Project Structure
```
backend/
├── app/
│   ├── models/
│   │   ├── habit.py              # UPDATE: Add reminder_time, reminder_days
│   │   └── habit_completion.py   # NEW: Completion records
│   ├── schemas/
│   │   └── habit.py              # UPDATE: Add completion schemas, update request
│   └── api/v1/endpoints/
│       └── habits.py             # UPDATE: Add PATCH, completion endpoints

ios/Scrollsmith/
├── Models/
│   ├── Habit.swift               # UPDATE: Add reminderTime, reminderDays
│   ├── HabitModels.swift         # UPDATE: Add HabitUpdateRequest, CompletionDTO
│   └── HabitCompletion.swift     # NEW: SwiftData completion model
├── Services/
│   ├── NotificationManager.swift # NEW: Schedule/cancel notifications
│   └── APIClient.swift           # UPDATE: PATCH habit, POST completion
├── ViewModels/
│   └── HabitListViewModel.swift  # NEW: Manage habit list + completions
└── Views/
    └── Habits/
        ├── HabitListView.swift       # NEW: List with streaks
        ├── HabitDetailView.swift     # NEW: Edit + calendar view
        ├── HabitRowView.swift        # NEW: Single habit with streak
        ├── StreakCalendarView.swift  # NEW: GitHub-style visualization
        └── NotificationPermissionView.swift  # NEW: Permission priming
```

### Pattern 1: Local Notification Scheduling with Actions
**What:** Schedule repeating calendar-based notifications with "Mark Complete" action button
**When to use:** Daily/weekly habit reminders
**Example:**
```swift
// Source: Apple Developer Documentation + Hacking with Swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    // Category identifier for habit reminders
    static let habitCategoryId = "HABIT_REMINDER"
    static let completeActionId = "COMPLETE_HABIT"

    func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: Self.completeActionId,
            title: "Mark Complete",
            options: []  // Empty = runs in background without opening app
        )

        let category = UNNotificationCategory(
            identifier: Self.habitCategoryId,
            actions: [completeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([category])
    }

    func scheduleHabitReminder(habit: Habit, time: DateComponents, days: [Int]?) async throws {
        // For daily habits, schedule once with repeats
        if habit.frequency == .daily {
            var components = time
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = createRequest(for: habit, trigger: trigger)
            try await center.add(request)
        } else if let days = days {
            // For weekly/3x weekly, schedule separate notification per day
            for day in days {
                var components = time
                components.weekday = day  // 1=Sunday, 2=Monday, etc.
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = createRequest(for: habit, trigger: trigger, daySuffix: "-\(day)")
                try await center.add(request)
            }
        }
    }

    private func createRequest(for habit: Habit, trigger: UNNotificationTrigger, daySuffix: String = "") -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.body = habit.title
        content.categoryIdentifier = Self.habitCategoryId
        content.userInfo = ["habitId": habit.id.uuidString]
        content.sound = .default

        return UNNotificationRequest(
            identifier: "habit-\(habit.id.uuidString)\(daySuffix)",
            content: content,
            trigger: trigger
        )
    }

    func cancelReminders(for habitId: UUID) {
        // Remove all notifications for this habit (handles daily + weekday variations)
        let identifiers = (1...7).map { "habit-\(habitId.uuidString)-\($0)" } + ["habit-\(habitId.uuidString)"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
```

### Pattern 2: Notification Action Handler (AppDelegate/SceneDelegate)
**What:** Handle "Mark Complete" action from notification without opening app
**When to use:** When user taps action button on notification
**Example:**
```swift
// Source: Apple Developer Documentation
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let habitId = response.notification.request.content.userInfo["habitId"] as? String

        switch response.actionIdentifier {
        case NotificationManager.completeActionId:
            // Mark habit complete in background
            if let habitIdString = habitId, let id = UUID(uuidString: habitIdString) {
                Task {
                    try? await APIClient.shared.completeHabit(habitId: id)
                    // Also update local SwiftData
                    await MainActor.run {
                        HabitCompletionStore.shared.recordCompletion(habitId: id)
                    }
                }
            }
        case UNNotificationDefaultActionIdentifier:
            // User tapped notification body - open app to habit
            if let habitIdString = habitId {
                DeepLinkHandler.shared.navigate(to: .habit(id: habitIdString))
            }
        default:
            break
        }

        completionHandler()
    }
}
```

### Pattern 3: PostgreSQL Streak Calculation with 1-Day Forgiveness
**What:** Calculate current/longest streak allowing a single missed day
**When to use:** Backend streak calculation on completion or on-demand
**Example:**
```python
# Source: PostgreSQL window function patterns + custom forgiveness logic
from sqlalchemy import text
from datetime import date, timedelta

async def calculate_streaks_with_forgiveness(
    db: AsyncSession,
    habit_id: UUID,
    user_timezone: str = "UTC"
) -> tuple[int, int]:
    """Calculate current and longest streak with 1-day forgiveness.

    Forgiveness means: if user misses exactly 1 day, streak continues.
    Two or more consecutive missed days breaks the streak.
    """
    # Get completion dates in user's local timezone
    query = text("""
        WITH completion_dates AS (
            SELECT DISTINCT
                (completed_at AT TIME ZONE :tz)::date AS completion_date
            FROM habit_completions
            WHERE habit_id = :habit_id
            ORDER BY completion_date
        ),
        -- Add gaps between consecutive dates
        with_gaps AS (
            SELECT
                completion_date,
                completion_date - LAG(completion_date) OVER (ORDER BY completion_date) AS gap
            FROM completion_dates
        ),
        -- Identify streak breaks (gaps > 2 days = break, gaps of 2 = forgiven)
        streak_groups AS (
            SELECT
                completion_date,
                gap,
                SUM(CASE WHEN gap IS NULL OR gap <= 2 THEN 0 ELSE 1 END)
                    OVER (ORDER BY completion_date) AS streak_id
            FROM with_gaps
        ),
        -- Calculate streak lengths
        streaks AS (
            SELECT
                streak_id,
                COUNT(*) AS streak_length,
                MAX(completion_date) AS streak_end
            FROM streak_groups
            GROUP BY streak_id
        )
        SELECT
            -- Current streak: only if last completion was today or yesterday
            COALESCE(
                (SELECT streak_length FROM streaks
                 WHERE streak_end >= CURRENT_DATE - INTERVAL '1 day'
                 ORDER BY streak_end DESC LIMIT 1),
                0
            ) AS current_streak,
            -- Longest streak ever
            COALESCE(MAX(streak_length), 0) AS longest_streak
        FROM streaks
    """)

    result = await db.execute(
        query,
        {"habit_id": str(habit_id), "tz": user_timezone}
    )
    row = result.fetchone()
    return row.current_streak, row.longest_streak
```

### Pattern 4: Timezone-Aware Completion Recording
**What:** Store completions with user's timezone for accurate day boundaries
**When to use:** Every habit completion
**Example:**
```python
# Source: Best practices for timezone handling
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

class HabitCompletionCreate(BaseModel):
    """Request to record a habit completion."""
    user_timezone: str = Field(
        default="UTC",
        description="IANA timezone identifier (e.g., 'America/New_York')"
    )

@router.post("/{habit_id}/complete", response_model=HabitCompletionResponse)
async def complete_habit(
    habit_id: UUID,
    request: HabitCompletionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> HabitCompletionResponse:
    """Record a habit completion.

    Always stores completed_at in UTC but preserves user_timezone
    for accurate streak calculation based on user's local midnight.
    """
    # Verify habit belongs to user
    habit = await get_habit_or_404(habit_id, current_user.id, db)

    # Store completion in UTC with timezone info
    completion = HabitCompletion(
        habit_id=habit_id,
        completed_at=datetime.now(timezone.utc),
        user_timezone=request.user_timezone,
    )
    db.add(completion)

    # Recalculate streaks
    current, longest = await calculate_streaks_with_forgiveness(
        db, habit_id, request.user_timezone
    )
    habit.current_streak = current
    habit.longest_streak = max(habit.longest_streak, longest)

    await db.commit()
    await db.refresh(completion)

    return HabitCompletionResponse(
        id=completion.id,
        habit_id=habit_id,
        completed_at=completion.completed_at,
        current_streak=habit.current_streak,
        longest_streak=habit.longest_streak,
    )
```

### Pattern 5: Notification Permission Priming (Pre-Permission Screen)
**What:** Show value proposition before iOS system prompt
**When to use:** Before first notification permission request
**Example:**
```swift
// Source: iOS UX best practices
struct NotificationPermissionView: View {
    @Environment(\.dismiss) var dismiss
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Stay on Track")
                .font(.title.bold())

            Text("Get gentle reminders at the times you choose. Perfect for building habits that stick.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Button("Enable Reminders") {
                    onAllow()
                }
                .buttonStyle(.borderedProminent)

                Button("Maybe Later") {
                    onSkip()
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(32)
    }
}

// Usage in HabitListViewModel
func requestNotificationPermission() async {
    let center = UNUserNotificationCenter.current()
    do {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        await MainActor.run {
            notificationsEnabled = granted
        }
    } catch {
        // Handle error
    }
}
```

### Anti-Patterns to Avoid
- **Storing times without timezone:** Always store `user_timezone` with completions for accurate streak calculation
- **Push notifications for reminders:** Use local notifications - simpler, works offline, no backend push infrastructure needed
- **Breaking streak on app-only miss:** If user does habit but forgets to tap app, that's a UX failure - implement retroactive completion
- **Complex calendar UI for ADHD users:** Keep visualization minimal - GitHub contribution style or simple streak counter
- **Requesting notification permission at launch:** Wait until user creates first habit with reminder

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Streak calculation | Custom loop in Python | PostgreSQL window functions | Database handles gaps, ordering, grouping efficiently |
| Calendar trigger scheduling | Timer-based approach | UNCalendarNotificationTrigger | Handles DST, device restarts, low power correctly |
| Timezone conversions | Manual offset math | Python zoneinfo / Swift TimeZone | Libraries handle DST transitions correctly |
| Contribution graph | Custom grid layout | Swift Charts or SwiftUI-ContributionChart | Accessibility, dark mode, localization handled |
| Notification categories | Inline action creation | Register once at app launch | System caches categories, must be registered before use |

**Key insight:** Local notifications are significantly simpler than push for habit reminders. No APNs certificates, no backend push service, works offline. Only use push if you need server-initiated notifications (which habits don't).

## Common Pitfalls

### Pitfall 1: Timezone Boundary Errors
**What goes wrong:** User completes habit at 11:50 PM local time, server in UTC records it as "tomorrow," breaking streak logic
**Why it happens:** Storing completion timestamps without preserving user's timezone
**How to avoid:**
- Always store `user_timezone` alongside `completed_at`
- Calculate streak using `completed_at AT TIME ZONE user_timezone` in SQL
- Never use server's local time for day boundaries
**Warning signs:** Users in different timezones report incorrect streaks

### Pitfall 2: 64 Notification Limit
**What goes wrong:** App schedules too many notifications and iOS silently drops some
**Why it happens:** iOS limits pending local notifications to 64 per app
**How to avoid:**
- Daily habits need only 1 notification (repeating)
- Weekly habits need at most 7 (one per day, repeating)
- Never schedule non-repeating notifications for future dates
- Track notification count and warn user if approaching limit
**Warning signs:** Users with many habits don't receive some reminders

### Pitfall 3: Notification Permission One-Shot
**What goes wrong:** User denies permission, app can never request again
**Why it happens:** iOS only allows one system permission prompt per app lifetime
**How to avoid:**
- Use pre-permission screen with clear value proposition
- If denied, show in-app reminder UI as fallback
- Provide Settings deep link for users who change their mind
- Check `UNAuthorizationStatus` before attempting to schedule
**Warning signs:** Users complain they can't enable notifications

### Pitfall 4: Orphaned Notifications on Habit Delete
**What goes wrong:** Deleted habit's notifications still fire, confusing users
**Why it happens:** Forgetting to cancel scheduled notifications when habit is deleted
**How to avoid:**
- Always call `cancelReminders(for: habitId)` when deleting habit
- Use consistent notification identifier pattern: `habit-{uuid}` and `habit-{uuid}-{weekday}`
- Cancel all variations of the identifier
**Warning signs:** Users receive reminders for deleted habits

### Pitfall 5: Streak Breaks from App-Only Miss
**What goes wrong:** User does the habit but forgets to open app, loses streak
**Why it happens:** No retroactive completion option
**How to avoid:**
- Allow completion for past dates (up to 1-2 days back)
- Show "Did you complete this yesterday?" prompt
- 1-day forgiveness in algorithm helps but doesn't fully solve
**Warning signs:** Users frustrated by lost streaks when they did complete habit

### Pitfall 6: Forgiveness Window Confusion
**What goes wrong:** 1-day forgiveness is misunderstood - users think they can skip any day
**Why it happens:** Unclear UX communication
**How to avoid:**
- Clearly label it as "one grace day" not unlimited skips
- Show visual indicator when grace day is used
- Reset grace after it's consumed
**Warning signs:** Users skip multiple days expecting streak to continue

## Code Examples

Verified patterns from official sources and existing codebase:

### HabitCompletion Backend Model
```python
# Source: Existing model patterns
from sqlalchemy import DateTime, String, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

class HabitCompletion(Base):
    """Record of a single habit completion."""

    __tablename__ = "habit_completions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    habit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("habits.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    completed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    user_timezone: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="UTC",
    )

    habit: Mapped["Habit"] = relationship("Habit", back_populates="completions")
```

### Habit Model Updates (Backend)
```python
# Source: Existing Habit model + requirements
# Add to existing Habit model:

from sqlalchemy import Time
from sqlalchemy.dialects.postgresql import ARRAY, INTEGER

class Habit(Base):
    # ... existing fields ...

    reminder_time: Mapped[Optional[time]] = mapped_column(
        Time,
        nullable=True,
        comment="Time of day for reminder (user's local time)"
    )
    reminder_days: Mapped[Optional[List[int]]] = mapped_column(
        ARRAY(INTEGER),
        nullable=True,
        comment="Days of week for reminder (1=Sun, 7=Sat). Null for daily."
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    # Relationship to completions
    completions: Mapped[List["HabitCompletion"]] = relationship(
        "HabitCompletion",
        back_populates="habit",
        cascade="all, delete-orphan",
    )
```

### HabitUpdateRequest Schema
```python
# Source: Existing PlaybookUpdate pattern
from datetime import time
from typing import Optional, List, Literal

class HabitUpdateRequest(BaseModel):
    """Request to update a habit. All fields optional for partial updates."""

    title: Optional[str] = Field(None, min_length=1, max_length=200)
    frequency: Optional[Literal["daily", "3x_weekly", "weekly"]] = None
    reminder_time: Optional[time] = Field(
        None,
        description="Time for reminder in HH:MM format"
    )
    reminder_days: Optional[List[int]] = Field(
        None,
        min_length=1,
        max_length=7,
        description="Days of week (1=Sun through 7=Sat)"
    )
    is_active: Optional[bool] = None
```

### PATCH Habit Endpoint
```python
# Source: Existing PATCH patterns in playbooks.py
@router.patch("/{habit_id}", response_model=HabitResponse)
async def update_habit(
    habit_id: UUID,
    request: HabitUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Habit:
    """Update a habit's details.

    Only provided fields are updated (partial update).
    Updating reminder_time triggers notification reschedule on iOS.
    """
    result = await db.execute(
        select(Habit).where(
            Habit.id == habit_id,
            Habit.user_id == current_user.id
        )
    )
    habit = result.scalar_one_or_none()

    if habit is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Habit not found"
        )

    # Apply updates
    if request.title is not None:
        habit.title = request.title
    if request.frequency is not None:
        habit.frequency = request.frequency
    if request.reminder_time is not None:
        habit.reminder_time = request.reminder_time
    if request.reminder_days is not None:
        habit.reminder_days = request.reminder_days
    if request.is_active is not None:
        habit.is_active = request.is_active

    await db.commit()
    await db.refresh(habit)

    return habit
```

### iOS SwiftData HabitCompletion Model
```swift
// Source: Existing SwiftData patterns
import Foundation
import SwiftData

@Model
class HabitCompletion {
    @Attribute(.unique) var id: UUID
    var habitId: UUID
    var completedAt: Date
    var userTimezone: String

    init(habitId: UUID, completedAt: Date = Date(), userTimezone: String = TimeZone.current.identifier) {
        self.id = UUID()
        self.habitId = habitId
        self.completedAt = completedAt
        self.userTimezone = userTimezone
    }
}
```

### iOS Habit Model Updates
```swift
// Source: Existing Habit.swift + requirements
import Foundation
import SwiftData

@Model
class Habit {
    @Attribute(.unique) var id: UUID
    var title: String
    var frequency: String
    var currentStreak: Int
    var longestStreak: Int
    var createdAt: Date

    // NEW fields for Phase 10
    var reminderTime: Date?  // Just time component matters
    var reminderDays: [Int]? // 1=Sun, 2=Mon, etc. Nil for daily
    var isActive: Bool
    var videoId: UUID?

    var user: User?
    var video: Video?

    init(
        id: UUID = UUID(),
        user: User,
        video: Video? = nil,
        title: String,
        frequency: String = "daily",
        reminderTime: Date? = nil,
        reminderDays: [Int]? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.user = user
        self.video = video
        self.videoId = video?.id
        self.title = title
        self.frequency = frequency
        self.reminderTime = reminderTime
        self.reminderDays = reminderDays
        self.isActive = isActive
        self.currentStreak = 0
        self.longestStreak = 0
        self.createdAt = Date()
    }
}
```

### Minimal Streak Visualization (Swift Charts)
```swift
// Source: Swift Charts documentation + habit tracker patterns
import SwiftUI
import Charts

struct StreakCalendarView: View {
    let completions: [Date]
    let weeksToShow: Int = 12

    var body: some View {
        Chart {
            ForEach(gridData, id: \.date) { item in
                RectangleMark(
                    xStart: .value("Week", item.week),
                    xEnd: .value("Week", item.week + 1),
                    yStart: .value("Day", item.dayOfWeek),
                    yEnd: .value("Day", item.dayOfWeek + 1)
                )
                .foregroundStyle(item.completed ? Color.green.opacity(0.8) : Color.gray.opacity(0.2))
                .cornerRadius(2)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 100)
    }

    private var gridData: [GridItem] {
        // Generate grid items for past N weeks
        let calendar = Calendar.current
        let today = Date()
        var items: [GridItem] = []

        for weekOffset in (0..<weeksToShow).reversed() {
            for dayOfWeek in 1...7 {
                var components = DateComponents()
                components.weekOfYear = -weekOffset
                components.weekday = dayOfWeek

                if let date = calendar.date(byAdding: components, to: today) {
                    let completed = completions.contains {
                        calendar.isDate($0, inSameDayAs: date)
                    }
                    items.append(GridItem(
                        date: date,
                        week: weeksToShow - weekOffset,
                        dayOfWeek: dayOfWeek,
                        completed: completed
                    ))
                }
            }
        }
        return items
    }

    struct GridItem {
        let date: Date
        let week: Int
        let dayOfWeek: Int
        let completed: Bool
    }
}
```

### In-App Reminder Fallback (When Notifications Denied)
```swift
// Source: iOS UX patterns
struct InAppReminderBanner: View {
    let habit: Habit
    @State private var dismissed = false

    var body: some View {
        if !dismissed && shouldShowReminder {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "bell.slash")
                    Text("Reminder: \(habit.title)")
                        .font(.subheadline.bold())
                    Spacer()
                    Button {
                        dismissed = true
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                Button("Mark Complete") {
                    // Complete habit
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color.yellow.opacity(0.2))
            .cornerRadius(12)
        }
    }

    private var shouldShowReminder: Bool {
        guard let reminderTime = habit.reminderTime else { return false }
        let calendar = Calendar.current
        let now = Date()
        let reminderHour = calendar.component(.hour, from: reminderTime)
        let currentHour = calendar.component(.hour, from: now)
        // Show if within reminder window and not completed today
        return currentHour >= reminderHour && !completedToday
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UILocalNotification | UNUserNotificationCenter | iOS 10 (2016) | Richer notifications, actions, categories |
| Push for all reminders | Local for scheduled, push for server-triggered | Best practice | Simpler, works offline, no certificates |
| FSCalendar (UIKit) | Swift Charts (native) | iOS 16 (2022) | Native SwiftUI, accessible, maintained |
| Server-side streak calculation only | Hybrid with local cache | 2024+ | Better offline UX, reduced API calls |

**Deprecated/outdated:**
- `UILocalNotification`: Deprecated since iOS 10, use `UNUserNotificationCenter`
- Push notifications for user-scheduled reminders: Overcomplicated, use local notifications
- Custom grid layouts for heatmaps: Swift Charts with RectangleMark handles this natively

## Open Questions

Things that couldn't be fully resolved:

1. **Weekly Habit Streak Definition**
   - What we know: Daily streaks are clear (consecutive days)
   - What's unclear: For 3x/week habits, what counts as "streak"? (3 completions per week? any completion per week?)
   - Recommendation: Count weeks with at least the target number of completions. A 3x/week habit maintains streak if 3+ completions per calendar week.

2. **Retroactive Completion Window**
   - What we know: Users may forget to mark habits but still did them
   - What's unclear: How far back should retroactive completion be allowed?
   - Recommendation: Allow completion for "yesterday" only (1 day back), matching forgiveness window

3. **Notification Identifier Collision**
   - What we know: Habit UUID is unique, used in notification identifier
   - What's unclear: What if user recreates habit with same title after delete?
   - Recommendation: UUID-based identifiers prevent collision. Old notifications auto-expire. No issue.

4. **Grace Day Visual Indicator**
   - What we know: 1-day forgiveness is implemented in algorithm
   - What's unclear: Should UI show when grace day is "used" vs "available"?
   - Recommendation: Simple approach for MVP - no visual indicator. Streak just doesn't break for 1 miss. Can add indicator in future iteration.

## Sources

### Primary (HIGH confidence)
- [Apple UNUserNotificationCenter Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Hacking with Swift: Scheduling Notifications](https://www.hackingwithswift.com/read/21/2/scheduling-notifications-unusernotificationcenter-and-unnotificationrequest)
- [Hacking with Swift: Acting on Notification Responses](https://www.hackingwithswift.com/read/21/3/acting-on-responses)
- [tanaschita.com: Custom Notification Actions](https://tanaschita.com/ios-notifications-custom-actions/)
- [PostgreSQL Streak Calculation](https://www.petergundel.de/postgresql/2023/04/23/streak-calculation-in-postgresql.html)
- Existing codebase: backend/app/api/v1/endpoints/habits.py (CRUD patterns)
- Existing codebase: backend/app/api/v1/endpoints/playbooks.py (PATCH pattern)
- Existing codebase: ios/Scrollsmith/Models/Habit.swift (SwiftData patterns)

### Secondary (MEDIUM confidence)
- [Trophy: Handling Time Zones in Gamification](https://trophy.so/blog/handling-time-zones-gamification)
- [DEV: SQL Streak Calculation](https://dev.to/keyridan/sql-story-of-unbroken-chains-of-events-streaks-3lh3)
- [Donnywals: Scheduling Daily Notifications](https://www.donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/)
- [UX Planet: iOS Permission Best Practices](https://uxplanet.org/getting-to-yes-best-practices-for-ios-permissions-dialogs-9d62892142cc)
- [SwiftUI-ContributionChart GitHub](https://github.com/VIkill33/SwiftUI-ContributionChart)
- [Swift Charts Contribution Graph Tutorial](https://artemnovichkov.com/blog/github-contribution-graph-swift-charts)

### Tertiary (LOW confidence)
- General habit tracking app patterns (multiple sources, ADHD-friendly design)
- Loop Habit Tracker algorithm patterns (open source reference)

## Metadata

**Confidence breakdown:**
- Local notifications: HIGH - Official Apple documentation, multiple verified tutorials
- Streak algorithm: HIGH - PostgreSQL patterns well-documented, timezone handling verified
- Notification actions: HIGH - Multiple official and verified tutorial sources
- Visualization: MEDIUM - Multiple approaches work, Swift Charts is native but less documented for heatmaps
- 1-day forgiveness: MEDIUM - Algorithm concept clear, specific implementation details are custom

**Research date:** 2026-01-26
**Valid until:** 2026-02-26 (30 days - stable domain, iOS notification APIs mature)
