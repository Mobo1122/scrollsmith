import SwiftUI

/// Compact usage indicator pill for navigation bar.
///
/// Shows "7/10" for free tier, "Pro" badge for Pro tier.
/// Tapping opens detailed usage sheet or upgrade prompt.
struct UsagePillView: View {
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: subscriptionViewModel.isPro ? "crown.fill" : "video.fill")
                .font(.caption2)

            Text(subscriptionViewModel.usageDisplayString)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(pillColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(pillBackground)
        .cornerRadius(16)
        .onTapGesture {
            subscriptionViewModel.showPaywall = true
        }
    }

    // MARK: - Styling

    private var pillColor: Color {
        if subscriptionViewModel.isPro {
            return .yellow
        } else if subscriptionViewModel.isNearLimit {
            return .orange
        } else {
            return .primary
        }
    }

    private var pillBackground: some ShapeStyle {
        if subscriptionViewModel.isPro {
            return AnyShapeStyle(.yellow.opacity(0.2))
        } else if subscriptionViewModel.isNearLimit {
            return AnyShapeStyle(.orange.opacity(0.2))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Free tier - low usage
        UsagePillView()
            .environmentObject({
                let vm = SubscriptionViewModel()
                return vm
            }())

        // Free tier - near limit
        UsagePillView()
            .environmentObject({
                let vm = SubscriptionViewModel()
                // Simulate near limit via private access (preview only)
                return vm
            }())

        // Pro tier
        UsagePillView()
            .environmentObject({
                let vm = SubscriptionViewModel()
                return vm
            }())
    }
    .padding()
}
