import Foundation
import SwiftUI

/// ViewModel for managing habit list, completions, and notifications.
@Observable
final class HabitListViewModel {
    var habits: [HabitDTO] = []
    var isLoading = false
    var error: String?
    var showingPermissionSheet = false
    var hasCheckedPermission = false
    var notificationsEnabled = false

    // MARK: - Computed Properties

    var todaysHabits: [HabitDTO] {
        habits.filter { shouldShowToday($0) }
    }

    var completedToday: Set<UUID> {
        // Track completions in memory for session
        // In real app, fetch from local SwiftData
        _completedToday
    }

    private var _completedToday: Set<UUID> = []

    // MARK: - Loading

    @MainActor
    func loadHabits() async {
        isLoading = true
        error = nil

        do {
            habits = try await APIClient.shared.getHabits()
            isLoading = false
        } catch {
            self.error = "Failed to load habits: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Completion

    @MainActor
    func completeHabit(_ habit: HabitDTO) async {
        do {
            _ = try await APIClient.shared.completeHabit(
                habitId: habit.id,
                timezone: TimeZone.current.identifier
            )

            // Update local state
            _completedToday.insert(habit.id)

            // Update habit in list with new streak
            if habits.firstIndex(where: { $0.id == habit.id }) != nil {
                // Refetch to get updated streak (simple approach)
                await loadHabits()
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

        } catch {
            self.error = "Failed to complete habit: \(error.localizedDescription)"
        }
    }

    func isCompletedToday(_ habit: HabitDTO) -> Bool {
        _completedToday.contains(habit.id)
    }

    // MARK: - Notifications

    @MainActor
    func checkNotificationPermission() async {
        guard !hasCheckedPermission else { return }
        hasCheckedPermission = true

        let notificationManager = NotificationManager.shared
        await notificationManager.checkAuthorizationStatus()
        notificationsEnabled = notificationManager.notificationsEnabled

        // If not determined and user has habits with reminders, show priming
        if notificationManager.authorizationStatus == .notDetermined {
            let hasReminders = habits.contains { $0.reminderTime != nil }
            if hasReminders {
                showingPermissionSheet = true
            }
        }
    }

    @MainActor
    func requestNotificationPermission() async -> Bool {
        do {
            let notificationManager = NotificationManager.shared
            let granted = try await notificationManager.requestAuthorization()
            notificationsEnabled = notificationManager.notificationsEnabled
            return granted
        } catch {
            self.error = "Failed to request notification permission"
            return false
        }
    }

    // MARK: - Helpers

    private func shouldShowToday(_ habit: HabitDTO) -> Bool {
        guard habit.isActive else { return false }

        // If daily, always show
        if habit.frequencyEnum == .daily {
            return true
        }

        // If specific days, check if today is in the list
        if let days = habit.reminderDays {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: Date()) // 1=Sunday
            return days.contains(weekday)
        }

        return true
    }
}
