import SwiftUI

/// Row view for a single habit with streak display and completion button.
struct HabitRowView: View {
    let habit: HabitDTO
    let isCompletedToday: Bool
    let onComplete: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Completion button
            Button(action: {
                if !isCompletedToday {
                    onComplete()
                }
            }) {
                Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompletedToday ? .green : .gray)
            }
            .buttonStyle(.plain)
            .disabled(isCompletedToday)

            // Habit info
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.body)
                    .foregroundColor(isCompletedToday ? .secondary : .primary)
                    .strikethrough(isCompletedToday)

                HStack(spacing: 12) {
                    // Frequency badge
                    Text(habit.frequencyEnum.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Streak display
                    if habit.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(habit.currentStreak)")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                    }
                }
            }

            Spacer()

            // Chevron for detail navigation
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
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
