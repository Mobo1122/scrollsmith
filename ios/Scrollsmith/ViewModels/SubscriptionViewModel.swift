import Foundation
import SwiftUI
import RevenueCat

/// Observable view model for subscription state and usage tracking.
///
/// Manages:
/// - Pro subscription status (from RevenueCat)
/// - Monthly video usage (from backend)
/// - Paywall presentation
///
/// Add to app environment alongside AuthViewModel.
@MainActor
class SubscriptionViewModel: ObservableObject {
    // MARK: - Published State

    /// Whether user has active Pro subscription.
    @Published private(set) var isPro: Bool = false

    /// Number of videos used this month (free tier only).
    @Published private(set) var videosUsed: Int = 0

    /// Video limit for current tier (10 for free, -1 for Pro/unlimited).
    @Published private(set) var videosLimit: Int = 10

    /// Whether user can create another video this month.
    @Published private(set) var canCreateVideo: Bool = true

    /// Date when usage resets (1st of next month).
    @Published private(set) var resetDate: Date = Date()

    /// Whether paywall sheet should be shown.
    @Published var showPaywall: Bool = false

    /// Whether a refresh is in progress.
    @Published private(set) var isLoading: Bool = false

    /// Error message to display, if any.
    @Published var errorMessage: String?

    // MARK: - Services

    private let subscriptionService = SubscriptionService.shared
    private let apiClient = APIClient.shared

    // MARK: - Refresh

    /// Refresh subscription status and usage from RevenueCat + backend.
    ///
    /// Call this:
    /// - After login/signup
    /// - After purchase completes
    /// - When app becomes active
    /// - Before creating a new video
    func refresh() async {
        isLoading = true
        errorMessage = nil

        // Check Pro status from RevenueCat (cached by SDK)
        isPro = await subscriptionService.isPro()

        // Fetch usage from backend
        do {
            let usage = try await apiClient.fetchUsage()
            videosUsed = usage.videosUsed
            videosLimit = usage.videosLimit
            canCreateVideo = usage.canCreateVideo

            // Parse reset date
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: usage.resetDate) {
                resetDate = date
            }
        } catch {
            errorMessage = "Failed to load usage status"
            print("⚠️ SubscriptionViewModel.refresh() error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchase Handling

    /// Handle successful purchase or restore.
    ///
    /// Call this from PaywallView's onPurchaseCompleted/onRestoreCompleted.
    func handlePurchaseSuccess() async {
        // Track Pro conversion
        Task {
            await AnalyticsService.shared.trackProConversion(source: "paywall")
        }

        await refresh()
        showPaywall = false
    }

    // MARK: - Usage Helpers

    /// Display string for usage pill (e.g., "7/10").
    var usageDisplayString: String {
        if isPro {
            return "Pro"
        } else {
            return "\(videosUsed)/\(videosLimit)"
        }
    }

    /// Progress fraction for usage indicator (0.0 to 1.0).
    var usageProgress: Double {
        guard videosLimit > 0 else { return 0.0 }
        return Double(videosUsed) / Double(videosLimit)
    }

    /// Whether usage is near limit (80%+).
    var isNearLimit: Bool {
        !isPro && usageProgress >= 0.8
    }
}
