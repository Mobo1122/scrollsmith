import SwiftUI

/// Row view for a single habit with streak display and completion button.
struct HabitRowView: View {
    let habit: HabitDTO
    let isCompletedToday: Bool
    let onComplete: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Animated completion button with celebration
            CompletionButton(
                isCompleted: isCompletedToday,
                onComplete: onComplete
            )

            // Habit info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(habit.title)
                    .font(Typography.body)
                    .foregroundColor(isCompletedToday ? Theme.Text.secondary : Theme.Text.primary)
                    .strikethrough(isCompletedToday)

                HStack(spacing: Spacing.sm) {
                    // Frequency badge
                    Text(habit.frequencyEnum.displayName)
                        .font(Typography.footnote)
                        .foregroundColor(Theme.Text.secondary)

                    // Streak display
                    if habit.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(Theme.Semantic.warning)
                            Text("\(habit.currentStreak)")
                                .fontWeight(.semibold)
                        }
                        .font(Typography.footnote)
                    }
                }
            }

            Spacer()

            // Chevron for detail navigation
            Image(systemName: "chevron.right")
                .font(Typography.footnote)
                .foregroundColor(Theme.Text.secondary)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Preview

#Preview {
    List {
        HabitRowView(
            habit: HabitDTO(
                id: UUID(),
                videoId: nil,
                title: "Meditate for 10 minutes",
                frequency: "daily",
                currentStreak: 5,
                longestStreak: 12,
                reminderTime: "09:00:00",
                reminderDays: nil,
                isActive: true,
                createdAt: Date()
            ),
            isCompletedToday: false,
            onComplete: {},
            onTap: {}
        )

        HabitRowView(
            habit: HabitDTO(
                id: UUID(),
                videoId: nil,
                title: "Read for 20 minutes",
                frequency: "daily",
                currentStreak: 0,
                longestStreak: 3,
                reminderTime: nil,
                reminderDays: nil,
                isActive: true,
                createdAt: Date()
            ),
            isCompletedToday: true,
            onComplete: {},
            onTap: {}
        )
    }
}
