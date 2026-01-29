import Foundation
import RevenueCat

/// Service for managing RevenueCat subscriptions and entitlements.
///
/// Wraps RevenueCat SDK for subscription status checks, purchases, and restores.
/// Configured after authentication with user's UUID as custom App User ID.
actor SubscriptionService {
    static let shared = SubscriptionService()

    private var isConfigured = false
    private let entitlementID = "Scrollsmith Pro"

    #if targetEnvironment(simulator)
    private let apiKey = "test_mVpCDZKcwncLwtHIsjlmGAWbTag"
    #else
    private let apiKey = "appl_xZlHeSQqvyNExlXwQOLgumOfbVz"
    #endif

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
        print("🔑 Using RevenueCat API key: \(apiKey.prefix(10))...")
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
    /// - Returns: True if "Scrollsmith Pro" entitlement is active, false otherwise
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

    // MARK: - Debug

    /// Debug function to check offerings configuration.
    func debugOfferings() async {
        print("🔍 RevenueCat Debug - isConfigured: \(isConfigured)")

        guard isConfigured else {
            print("❌ RevenueCat not configured")
            return
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            print("🔍 Offerings: \(offerings)")
            print("🔍 Current offering: \(String(describing: offerings.current))")
            print("🔍 All offerings: \(offerings.all.keys)")

            if let current = offerings.current {
                print("🔍 Packages in current offering: \(current.availablePackages.count)")
                for package in current.availablePackages {
                    print("  📦 Package: \(package.identifier) - \(package.storeProduct.productIdentifier)")
                }
            }
        } catch {
            print("❌ Failed to fetch offerings: \(error)")
        }

        // Also try fetching products directly from StoreKit
        let products = await Purchases.shared.products(["scrollsmith_monthly", "scrollsmith_yearly"])
        print("🔍 Direct product fetch: \(products.count) products")
        for product in products {
            print("  🏷️ Product: \(product.productIdentifier) - \(product.localizedTitle)")
        }
    }

    // MARK: - Offerings

    /// Fetch available subscription packages from RevenueCat.
    ///
    /// Returns packages from the current offering (configured in RevenueCat dashboard).
    /// Use this to display subscription options in a custom paywall.
    ///
    /// - Returns: Array of available packages (monthly, yearly, etc.)
    func fetchPackages() async throws -> [Package] {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        let offerings = try await Purchases.shared.offerings()

        guard let current = offerings.current else {
            throw SubscriptionError.noOfferings
        }

        return current.availablePackages
    }

    // MARK: - Purchase

    /// Purchase a subscription package.
    ///
    /// Initiates StoreKit purchase flow for the selected package.
    /// RevenueCat handles receipt validation and entitlement provisioning.
    ///
    /// - Parameter package: The package to purchase (from fetchPackages)
    /// - Returns: True if Pro entitlement is now active after purchase
    func purchase(_ package: Package) async throws -> Bool {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        let result = try await Purchases.shared.purchase(package: package)

        // Check if user cancelled (not an error, just return false)
        if result.userCancelled {
            return false
        }

        return result.customerInfo.entitlements[entitlementID]?.isActive == true
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
    case noOfferings
    case purchaseFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Subscription service not configured. Please log in first."
        case .noOfferings:
            return "No subscription plans available. Please try again later."
        case .purchaseFailed(let reason):
            return "Purchase failed: \(reason)"
        }
    }
}
