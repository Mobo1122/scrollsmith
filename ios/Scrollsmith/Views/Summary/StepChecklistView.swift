import SwiftUI

/// Interactive step-by-step checklist with timeline and completion tracking.
///
/// CONTEXT.md decisions:
/// - Timeline on left edge with dots showing visual progression
/// - Interactive checkboxes for completion tracking
/// - Step completion state persists per video
struct StepChecklistView: View {
    let checklist: StepChecklist
    let videoId: UUID
    let sourceUrl: String?
    @Bindable var viewModel: SummaryViewModel

    private let deepLinkService = DeepLinkService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title with duration
                titleSection

                // Steps with timeline
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(checklist.steps.enumerated()), id: \.element.id) { index, step in
                        StepRow(
                            step: step,
                            isLast: index == checklist.steps.count - 1,
                            isComplete: viewModel.isStepComplete(step.stepNumber),
                            onToggle: { viewModel.toggleStepCompletion(step.stepNumber) },
                            onTimestampTap: { handleTimestampTap(step.timestampSeconds) }
                        )
                    }
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.loadStepCompletion(for: videoId)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(checklist.title)
                .font(.title2)
                .fontWeight(.semibold)

            if let duration = checklist.estimatedDurationMinutes {
                Text("\(duration) min estimated")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Timestamp Handling

    private func handleTimestampTap(_ seconds: Int?) {
        guard let seconds, let sourceUrl else { return }

        if let platform = DeepLinkService.Platform.from(sourceUrl: sourceUrl) {
            switch platform {
            case .youtube(let videoId, _):
                deepLinkService.open(.youtube(videoId: videoId, timestampSeconds: seconds))
            default:
                // Other platforms don't support timestamp linking
                deepLinkService.open(platform)
            }
        }
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let step: StepItem
    let isLast: Bool
    let isComplete: Bool
    let onToggle: () -> Void
    let onTimestampTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline with checkbox
            timelineColumn

            // Content
            contentColumn
        }
        .padding(.bottom, isLast ? 0 : 16)
    }

    // MARK: - Timeline Column

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            // Checkbox circle
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(isComplete ? Color.green : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text("\(step.stepNumber)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Connecting line (if not last)
            if !isLast {
                Rectangle()
                    .fill(isComplete ? Color.green.opacity(0.5) : Color.gray.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 24)
    }

    // MARK: - Content Column

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.instruction)
                .font(.body)
                .foregroundStyle(isComplete ? .secondary : .primary)
                .strikethrough(isComplete, color: .secondary)
                .lineSpacing(4)

            // Timestamp button (if available)
            if let seconds = step.timestampSeconds {
                Button(action: onTimestampTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.caption)
                        Text(formatTimestamp(seconds))
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formatTimestamp(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Empty State

extension StepChecklistView {
    static var empty: some View {
        ContentUnavailableView {
            Label("No Steps", systemImage: "checklist")
        } description: {
            Text("This video doesn't have a step-by-step checklist.")
        }
    }
}

#Preview {
    let checklist = StepChecklist(
        title: "Morning Routine for Productivity",
        steps: [
            StepItem(stepNumber: 1, instruction: "Wake up at 5:30 AM without hitting snooze", timestampSeconds: 30),
            StepItem(stepNumber: 2, instruction: "Drink a full glass of water before anything else", timestampSeconds: 90),
            StepItem(stepNumber: 3, instruction: "Do 10 minutes of stretching or light exercise", timestampSeconds: 180),
            StepItem(stepNumber: 4, instruction: "Write down your top 3 priorities for the day", timestampSeconds: 300),
            StepItem(stepNumber: 5, instruction: "Start your first task before checking email or social media", timestampSeconds: nil)
        ],
        estimatedDurationMinutes: 30
    )

    return StepChecklistView(
        checklist: checklist,
        videoId: UUID(),
        sourceUrl: "https://youtube.com/watch?v=test123",
        viewModel: SummaryViewModel()
    )
}
