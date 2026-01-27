import SwiftUI

/// Main view for displaying and managing habits.
struct HabitListView: View {
    @State private var viewModel = HabitListViewModel()
    @State private var selectedHabit: HabitDTO?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.habits.isEmpty {
                    ProgressView("Loading habits...")
                } else if viewModel.habits.isEmpty {
                    emptyStateView
                } else {
                    habitList
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.notificationsEnabled && !viewModel.habits.isEmpty {
                        Button {
                            viewModel.showingPermissionSheet = true
                        } label: {
                            Image(systemName: "bell.slash")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadHabits()
            }
            .task {
                await viewModel.loadHabits()
                await viewModel.checkNotificationPermission()
            }
            .sheet(isPresented: $viewModel.showingPermissionSheet) {
                NotificationPermissionView(
                    onAllow: {
                        _ = await viewModel.requestNotificationPermission()
                        viewModel.showingPermissionSheet = false
                    },
                    onSkip: {
                        viewModel.showingPermissionSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
            .navigationDestination(item: $selectedHabit) { habit in
                HabitDetailView(
                    habit: habit,
                    onDelete: {
                        do {
                            try await APIClient.shared.deleteHabit(habitId: habit.id)
                            await viewModel.loadHabits()
                        } catch {
                            viewModel.error = "Failed to delete habit"
                        }
                    },
                    onUpdate: { request in
                        do {
                            _ = try await APIClient.shared.updateHabit(habitId: habit.id, request: request)
                            await viewModel.loadHabits()
                            return true
                        } catch {
                            viewModel.error = "Failed to update habit"
                            return false
                        }
                    }
                )
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var habitList: some View {
        List {
            // In-app reminder banner if notifications denied
            if !viewModel.notificationsEnabled {
                inAppReminderBanner
            }

            // Today's habits section
            if !viewModel.todaysHabits.isEmpty {
                Section("Today") {
                    ForEach(viewModel.todaysHabits) { habit in
                        HabitRowView(
                            habit: habit,
                            isCompletedToday: viewModel.isCompletedToday(habit),
                            onComplete: {
                                Task { await viewModel.completeHabit(habit) }
                            },
                            onTap: {
                                selectedHabit = habit
                            }
                        )
                    }
                }
            }

            // All habits section
            Section("All Habits") {
                ForEach(viewModel.habits) { habit in
                    HabitRowView(
                        habit: habit,
                        isCompletedToday: viewModel.isCompletedToday(habit),
                        onComplete: {
                            Task { await viewModel.completeHabit(habit) }
                        },
                        onTap: {
                            selectedHabit = habit
                        }
                    )
                }
            }
        }
    }

    private var inAppReminderBanner: some View {
        HStack {
            Image(systemName: "bell.slash")
                .foregroundColor(.orange)
            VStack(alignment: .leading) {
                Text("Notifications Off")
                    .font(.subheadline.bold())
                Text("Enable to get habit reminders")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Enable") {
                viewModel.showingPermissionSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Habits Yet",
            systemImage: "checkmark.circle",
            description: Text("Create habits from your saved videos to start tracking your progress.")
        )
    }
}

#Preview {
    HabitListView()
}
