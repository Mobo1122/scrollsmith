import SwiftUI

/// Pre-permission screen explaining value of notifications before iOS prompt.
struct NotificationPermissionView: View {
    let onAllow: () async -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Stay on Track")
                .font(.title.bold())

            Text("Get gentle reminders at the times you choose. Perfect for building habits that stick.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await onAllow() }
                } label: {
                    Text("Enable Reminders")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Maybe Later", action: onSkip)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    NotificationPermissionView(
        onAllow: {},
        onSkip: {}
    )
}
