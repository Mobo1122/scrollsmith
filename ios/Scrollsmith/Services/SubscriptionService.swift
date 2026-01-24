import Foundation
import RevenueCat

/// Service for managing RevenueCat subscriptions and entitlements.
///
/// Wraps RevenueCat SDK for subscription status checks, purchases, and restores.
/// Configured after authentication with user's UUID as custom App User ID.
actor SubscriptionService {
    static let shared = SubscriptionService()

    private var isConfigured = false
    private let entitlementID = "pro"
    private let apiKey = "test_mVpCDZKcwncLwtHIsjlmGAWbTag"

    private init() {}

    // MARK: - Configuration

    /// Configure RevenueCat SDK with authenticated user's ID.
    ///
    /// Call this after login/signup completes. Using custom App User IDs ensures
    /// subscription status syncs across devices and prevents anonymous ID issues.
    ///
    /// - Parameter userId: The authenticated user's UUID from backend
    func configure(userId: UUID) {
        guard !isConfigured else { return }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(
            withAPIKey: apiKey,
            appUserID: userId.uuidString.lowercased()
        )

        isConfigured = true
    }

    /// Reset configuration state (for logout).
    ///
    /// Note: We don't call Purchases.shared.logOut() to avoid creating anonymous IDs.
    /// Just clear our flag and reconfigure on next login.
    func reset() {
        isConfigured = false
    }

    // MARK: - Entitlement Checks

    /// Check if user has active Pro subscription.
    ///
    /// Returns cached result from RevenueCat SDK (refreshed every ~5 minutes).
    /// Fails closed - returns false on error to avoid granting access incorrectly.
    ///
    /// - Returns: True if "pro" entitlement is active, false otherwise
    func isPro() async -> Bool {
        guard isConfigured else { return false }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements[entitlementID]?.isActive == true
        } catch {
            // Fail closed - don't grant Pro access on network errors
            print("⚠️ SubscriptionService.isPro() error: \(error.localizedDescription)")
            return false
        }
    }

    /// Get full customer info from RevenueCat.
    ///
    /// Use this sparingly - prefer `isPro()` for simple checks.
    /// This returns the full subscription status including expiration dates.
    ///
    /// - Returns: CustomerInfo object from RevenueCat SDK
    func customerInfo() async throws -> CustomerInfo {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }
        return try await Purchases.shared.customerInfo()
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases from App Store.
    ///
    /// Call this when user taps "Restore Purchases" in Settings.
    /// RevenueCat syncs purchases from App Store and returns updated status.
    ///
    /// - Returns: True if Pro entitlement is now active after restore
    func restorePurchases() async throws -> Bool {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        let customerInfo = try await Purchases.shared.restorePurchases()
        return customerInfo.entitlements[entitlementID]?.isActive == true
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Subscription service not configured. Please log in first."
        }
    }
}
