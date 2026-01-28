import SwiftUI
import RevenueCat
import RevenueCatUI

/// Paywall view using RevenueCatUI's pre-built paywall.
///
/// Displays products, pricing, and handles purchase flow.
/// Configure products and offerings in RevenueCat dashboard.
struct ScrollsmithPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    var body: some View {
        // Note: Paywall styling is configured in RevenueCat dashboard
        // Set accent color to match brand violet (#7C3AED)
        PaywallView()
            .onPurchaseCompleted { customerInfo in
                Task {
                    await subscriptionViewModel.handlePurchaseSuccess()
                    dismiss()
                }
            }
            .onRestoreCompleted { customerInfo in
                Task {
                    await subscriptionViewModel.handlePurchaseSuccess()
                    dismiss()
                }
            }
            .tint(Theme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .tint(Theme.accent)
                }
            }
    }
}

#Preview {
    NavigationStack {
        ScrollsmithPaywallView()
            .environmentObject(SubscriptionViewModel())
    }
}
