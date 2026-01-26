import SwiftUI

/// Sheet displaying habit suggestions with selection and frequency options.
///
/// Flow:
/// 1. Shows loading state while extracting
/// 2. Shows 1-3 habit suggestions with checkboxes
/// 3. Shows frequency picker for each selected habit
/// 4. User taps "Create Habits" to save selected habits
@MainActor
struct HabitExtractionSheet: View {
    let videoId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = HabitExtractionViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Action Points")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        if case .suggestions = viewModel.state {
                            Button("Create") {
                                Task {
                                    await viewModel.createSelectedHabits()
                                }
                            }
                            .disabled(!viewModel.hasSelections || viewModel.isLoading)
                        }
                    }
                }
        }
        .task {
            await viewModel.extractHabits(from: videoId)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView

        case .suggestions(let items):
            suggestionsList(items)

        case .creating:
            creatingView

        case .success(let count):
            successView(count: count)

        case .error(let message):
            errorView(message: message)

        case .proRequired:
            // Should not happen - sheet shouldn't open for free users
            // But handle gracefully
            proRequiredView
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing video...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Finding actionable habits from your video")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Suggestions List

    private func suggestionsList(_ items: [HabitSelectionState]) -> some View {
        List {
            Section {
                Text("Select which habits to create and set how often you want to be reminded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Suggested Habits") {
                ForEach(items) { item in
                    HabitSuggestionRow(
                        item: item,
                        onToggle: {
                            viewModel.toggleSelection(for: item.id)
                        },
                        onFrequencyChange: { frequency in
                            viewModel.updateFrequency(for: item.id, to: frequency)
                        }
                    )
                }
            }

            if viewModel.selectedCount > 0 {
                Section {
                    HStack {
                        Text("Selected")
                        Spacer()
                        Text("\(viewModel.selectedCount) habit\(viewModel.selectedCount == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Creating

    private var creatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Creating habits...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success

    private func successView(count: Int) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("\(count) Habit\(count == 1 ? "" : "s") Created!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You'll find your new habits in the Habits tab.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Extraction Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.extractHabits(from: videoId)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Pro Required

    private var proRequiredView: some View {
        ContentUnavailableView {
            Label("Pro Required", systemImage: "lock.fill")
        } description: {
            Text("Habit extraction requires a Pro subscription.")
        } actions: {
            Button("Dismiss") {
                dismiss()
            }
        }
    }
}

// MARK: - Habit Suggestion Row

private struct HabitSuggestionRow: View {
    let item: HabitSelectionState
    let onToggle: () -> Void
    let onFrequencyChange: (HabitFrequency) -> Void

    @State private var frequency: HabitFrequency

    init(item: HabitSelectionState, onToggle: @escaping () -> Void, onFrequencyChange: @escaping (HabitFrequency) -> Void) {
        self.item = item
        self.onToggle = onToggle
        self.onFrequencyChange = onFrequencyChange
        self._frequency = State(initialValue: item.frequency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row with checkbox
            HStack(alignment: .top, spacing: 12) {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isSelected ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.suggestion.title)
                        .font(.headline)

                    Text(item.suggestion.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            // Frequency picker (only when selected)
            if item.isSelected {
                FrequencyPickerView(frequency: $frequency)
                    .onChange(of: frequency) { _, newValue in
                        onFrequencyChange(newValue)
                    }
                    .padding(.leading, 44) // Align with text
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: item.isSelected)
    }
}

#Preview("Loading") {
    HabitExtractionSheet(videoId: UUID())
}
