import SwiftUI

/// Detail view for a habit showing streak calendar, stats, and actions.
struct HabitDetailView: View {
    let habit: HabitDTO
    let onDelete: () async -> Void
    let onUpdate: (HabitUpdateRequest) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var completionDates: [Date] = []
    @State private var isLoadingCompletions = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with streak stats
                streakHeader

                // Calendar visualization
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.headline)
                    StreakCalendarView(completions: completionDates, weeksToShow: 12)
                }
                .padding(.horizontal)

                // Details section
                detailsSection

                // Source video link
                if habit.videoId != nil {
                    sourceVideoSection
                }

                // Delete button
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Habit", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(habit.title)
                    .font(Typography.title3)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            HabitEditSheet(
                habit: habit,
                onSave: { request in
                    let success = await onUpdate(request)
                    if success {
                        // Reschedule notifications if reminder changed
                        if request.reminderTime != nil {
                            await rescheduleNotifications(request)
                        }
                    }
                    return success
                },
                onCancel: { showingEditSheet = false }
            )
        }
        .confirmationDialog(
            "Delete Habit",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    isDeleting = true
                    await onDelete()
                    // Cancel notifications
                    NotificationManager.shared.cancelReminders(for: habit.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(habit.title)\" and all its history. This cannot be undone.")
        }
        .task {
            await loadCompletions()
        }
        .overlay {
            if isDeleting {
                ProgressView("Deleting...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
            }
        }
    }

    private var streakHeader: some View {
        HStack(spacing: 32) {
            VStack {
                Text("\(habit.currentStreak)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(habit.currentStreak > 0 ? .orange : .secondary)
                Text("Current")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                Text("\(habit.longestStreak)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("Longest")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                Text("\(completionDates.count)")
                    .font(.system(size: 36, weight: .bold))
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            HStack {
                Label(habit.frequencyEnum.description, systemImage: "repeat")
                Spacer()
            }

            if let timeString = habit.reminderTime {
                HStack {
                    Label("Reminder at \(formatTime(timeString))", systemImage: "bell")
                    Spacer()
                }
            }

            HStack {
                Label("Created \(habit.createdAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Spacer()
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding(.horizontal)
    }

    private var sourceVideoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.headline)

            NavigationLink {
                // Navigate to video detail - requires Video lookup
                Text("Video Detail")
            } label: {
                HStack {
                    Image(systemName: "play.rectangle")
                    Text("View Original Video")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    /// Fetch real completion history from the API endpoint (GET /habits/{id}/completions).
    private func loadCompletions() async {
        isLoadingCompletions = true
        do {
            let completions = try await APIClient.shared.getHabitCompletions(habitId: habit.id)
            completionDates = completions.map { $0.completedAt }
        } catch {
            // On error, fall back to estimating from streak (graceful degradation)
            let calendar = Calendar.current
            let today = Date()
            completionDates = (0..<habit.currentStreak).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: today)
            }
            print("Failed to load completions, using streak estimate: \(error)")
        }
        isLoadingCompletions = false
    }

    private func formatTime(_ timeString: String) -> String {
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return timeString }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if let date = Calendar.current.date(from: components) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return timeString
    }

    private func rescheduleNotifications(_ request: HabitUpdateRequest) async {
        guard let timeString = request.reminderTime else { return }
        let parts = timeString.split(separator: ":")
        guard let hour = Int(parts[0]), let minute = Int(parts[1]) else { return }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        do {
            try await NotificationManager.shared.scheduleHabitReminder(
                habitId: habit.id,
                title: request.title ?? habit.title,
                time: components,
                days: request.reminderDays ?? habit.reminderDays
            )
        } catch {
            print("Failed to reschedule notifications: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(
            habit: HabitDTO(
                id: UUID(),
                videoId: UUID(),
                title: "Meditate for 10 minutes",
                frequency: "daily",
                currentStreak: 5,
                longestStreak: 12,
                reminderTime: "09:00:00",
                reminderDays: nil,
                isActive: true,
                createdAt: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            ),
            onDelete: {},
            onUpdate: { _ in true }
        )
    }
}
