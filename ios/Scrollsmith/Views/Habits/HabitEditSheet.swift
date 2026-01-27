import SwiftUI

/// Sheet for editing habit title, frequency, and reminder settings.
struct HabitEditSheet: View {
    let habit: HabitDTO
    let onSave: (HabitUpdateRequest) async -> Bool
    let onCancel: () -> Void

    @State private var title: String
    @State private var frequency: HabitFrequency
    @State private var hasReminder: Bool
    @State private var reminderTime: Date
    @State private var reminderDays: Set<Int>
    @State private var isSaving = false

    init(
        habit: HabitDTO,
        onSave: @escaping (HabitUpdateRequest) async -> Bool,
        onCancel: @escaping () -> Void
    ) {
        self.habit = habit
        self.onSave = onSave
        self.onCancel = onCancel

        _title = State(initialValue: habit.title)
        _frequency = State(initialValue: habit.frequencyEnum)
        _hasReminder = State(initialValue: habit.reminderTime != nil)

        // Parse existing reminder time or default to 9 AM
        if let components = habit.reminderTimeComponents {
            var dateComponents = DateComponents()
            dateComponents.hour = components.hour
            dateComponents.minute = components.minute
            _reminderTime = State(initialValue: Calendar.current.date(from: dateComponents) ?? Date())
        } else {
            var defaultTime = DateComponents()
            defaultTime.hour = 9
            defaultTime.minute = 0
            _reminderTime = State(initialValue: Calendar.current.date(from: defaultTime) ?? Date())
        }

        _reminderDays = State(initialValue: Set(habit.reminderDays ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Title", text: $title)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section("Reminder") {
                    Toggle("Enable Reminder", isOn: $hasReminder)

                    if hasReminder {
                        DatePicker(
                            "Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )

                        if frequency != .daily {
                            dayPicker
                        }
                    }
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach([1, 2, 3, 4, 5, 6, 7], id: \.self) { day in
                    DayToggle(
                        day: day,
                        isSelected: reminderDays.contains(day),
                        onToggle: {
                            if reminderDays.contains(day) {
                                reminderDays.remove(day)
                            } else {
                                reminderDays.insert(day)
                            }
                        }
                    )
                }
            }
        }
    }

    private func save() async {
        isSaving = true

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        let timeString = hasReminder ? String(format: "%02d:%02d", hour, minute) : nil

        let request = HabitUpdateRequest(
            title: title != habit.title ? title : nil,
            frequency: frequency.rawValue != habit.frequency ? frequency.rawValue : nil,
            reminderTime: timeString,
            reminderDays: hasReminder && frequency != .daily ? Array(reminderDays).sorted() : nil,
            isActive: nil
        )

        let success = await onSave(request)
        isSaving = false

        if success {
            onCancel() // Dismiss
        }
    }
}

struct DayToggle: View {
    let day: Int
    let isSelected: Bool
    let onToggle: () -> Void

    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        Button(action: onToggle) {
            Text(dayNames[day - 1])
                .font(.caption.bold())
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HabitEditSheet(
        habit: HabitDTO(
            id: UUID(),
            videoId: nil,
            title: "Meditate",
            frequency: "daily",
            currentStreak: 5,
            longestStreak: 12,
            reminderTime: "09:00:00",
            reminderDays: nil,
            isActive: true,
            createdAt: Date()
        ),
        onSave: { _ in true },
        onCancel: {}
    )
}
