import Foundation
import UserNotifications

/// Manages local notifications for habit reminders.
/// Uses UNCalendarNotificationTrigger for repeating schedules.
@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    // Notification identifiers
    static let habitCategoryId = "HABIT_REMINDER"
    static let completeActionId = "COMPLETE_HABIT"

    private let center = UNUserNotificationCenter.current()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var notificationsEnabled = false

    override init() {
        super.init()
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Permission Handling

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    func requestAuthorization() async throws -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Notification permission error: \(error)")
            throw error
        }
    }

    // MARK: - Category Registration

    func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: Self.completeActionId,
            title: "Mark Complete",
            options: []  // Runs in background without opening app
        )

        let category = UNNotificationCategory(
            identifier: Self.habitCategoryId,
            actions: [completeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([category])
    }

    // MARK: - Scheduling

    /// Schedule a habit reminder notification.
    /// - Parameters:
    ///   - habitId: The habit ID to schedule reminders for
    ///   - title: The habit title to show in notification
    ///   - time: Time of day components (hour, minute)
    ///   - days: Specific weekdays (1=Sunday through 7=Saturday). Nil for daily.
    func scheduleHabitReminder(
        habitId: UUID,
        title: String,
        time: DateComponents,
        days: [Int]?
    ) async throws {
        // Remove any existing notifications for this habit first
        cancelReminders(for: habitId)

        if let days = days, !days.isEmpty {
            // Non-daily: schedule separate notification per weekday
            for day in days {
                var components = time
                components.weekday = day
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = createRequest(habitId: habitId, title: title, trigger: trigger, daySuffix: "-\(day)")
                try await center.add(request)
            }
        } else {
            // Daily: single repeating notification
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            let request = createRequest(habitId: habitId, title: title, trigger: trigger)
            try await center.add(request)
        }

        print("Scheduled reminder for habit \(habitId)")
    }

    private func createRequest(
        habitId: UUID,
        title: String,
        trigger: UNNotificationTrigger,
        daySuffix: String = ""
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.body = title
        content.categoryIdentifier = Self.habitCategoryId
        content.userInfo = ["habitId": habitId.uuidString]
        content.sound = .default

        return UNNotificationRequest(
            identifier: "habit-\(habitId.uuidString)\(daySuffix)",
            content: content,
            trigger: trigger
        )
    }

    // MARK: - Cancellation

    func cancelReminders(for habitId: UUID) {
        // Remove all variations: daily + each weekday
        var identifiers = ["habit-\(habitId.uuidString)"]
        for day in 1...7 {
            identifiers.append("habit-\(habitId.uuidString)-\(day)")
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled reminders for habit \(habitId)")
    }

    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is open
        completionHandler([.banner, .sound])
    }

    /// Handle notification action (Mark Complete button or tap)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let habitIdString = response.notification.request.content.userInfo["habitId"] as? String

        switch response.actionIdentifier {
        case Self.completeActionId:
            // User tapped "Mark Complete" action
            if let habitIdString = habitIdString, let habitId = UUID(uuidString: habitIdString) {
                Task {
                    await completeHabitFromNotification(habitId: habitId)
                }
            }

        case UNNotificationDefaultActionIdentifier:
            // User tapped notification body - could navigate to habit
            // For now, just open app (default behavior)
            break

        default:
            break
        }

        completionHandler()
    }

    private func completeHabitFromNotification(habitId: UUID) async {
        do {
            // Call API to complete habit
            _ = try await APIClient.shared.completeHabit(habitId: habitId, timezone: TimeZone.current.identifier)
            print("Completed habit \(habitId) from notification")
        } catch {
            print("Failed to complete habit from notification: \(error)")
        }
    }
}
