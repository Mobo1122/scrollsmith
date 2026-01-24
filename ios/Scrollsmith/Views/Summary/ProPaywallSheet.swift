import SwiftUI

/// Bottom sheet paywall for Pro format access.
///
/// CONTEXT.md decisions:
/// - Bottom sheet (not full redirect)
/// - Explains what Pro unlocks and how it helps
/// - Two actions: "Upgrade to Pro" (primary) + "Not now" (secondary)
/// - Contextual trigger only
struct ProPaywallSheet: View {
    let requestedFormat: SummaryFormat
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            header

            // Benefits list
            benefitsList

            // Actions
            actionButtons
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: formatIcon)
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("\(requestedFormat.rawValue) is a Pro Feature")
                .font(.title2)
                .fontWeight(.bold)

            Text("Unlock \(requestedFormat.rawValue.lowercased()) summaries and more with Scrollsmith Pro.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var formatIcon: String {
        switch requestedFormat {
        case .bullets: return "list.bullet"
        case .steps: return "checklist"
        case .cards: return "rectangle.stack"
        }
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(icon: "checklist", text: "Step-by-step checklists with timestamps")
            benefitRow(icon: "rectangle.stack", text: "Swipeable card summaries")
            benefitRow(icon: "infinity", text: "Unlimited video summaries")
            benefitRow(icon: "bolt.fill", text: "Habit extraction from videos")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary - Upgrade
            Button {
                // TODO: Phase 8 will implement RevenueCat purchase flow
                // For now, just dismiss
                dismiss()
            } label: {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.linearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .foregroundColor(.white)
            }

            // Secondary - Not now
            Button {
                dismiss()
            } label: {
                Text("Not now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    Text("Trigger Sheet")
        .sheet(isPresented: .constant(true)) {
            ProPaywallSheet(requestedFormat: .steps)
        }
}
