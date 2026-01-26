import SwiftUI
import SwiftData
import RevenueCat
import UserNotifications

@main
struct ScrollsmithApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    @StateObject private var uploadQueueService = UploadQueueService.shared
    @Environment(\.scenePhase) private var scenePhase

    /// Shared model container for extension communication.
    private let sharedContainer = SharedModelContainer.shared

    init() {
        // Clear stale Keychain items on first launch after reinstall
        // Keychain items persist after app uninstall, which can cause issues
        clearKeychainOnFirstLaunch()

        // Register notification categories on launch
        NotificationManager.shared.registerCategories()

        // Set notification delegate for handling actions
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(subscriptionViewModel)
                .environmentObject(uploadQueueService)
                .onAppear {
                    // Configure upload queue with shared container
                    let context = sharedContainer.mainContext
                    uploadQueueService.configure(with: context)
                }
                .onChange(of: authViewModel.currentUser) { _, newUser in
                    // Configure RevenueCat when user logs in
                    if let userId = newUser?.id {
                        Task {
                            await SubscriptionService.shared.configure(userId: userId)
                            await subscriptionViewModel.refresh()
                        }
                    } else {
                        // User logged out - reset subscription state
                        Task {
                            await SubscriptionService.shared.reset()
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Process pending uploads when app becomes active
                        Task {
                            await uploadQueueService.refreshPendingCount()
                            await uploadQueueService.processQueue()

                            // Refresh subscription status
                            if authViewModel.currentUser != nil {
                                await subscriptionViewModel.refresh()
                            }
                        }
                    }
                }
                .sheet(isPresented: $subscriptionViewModel.showPaywall) {
                    NavigationStack {
                        ScrollsmithPaywallView()
                    }
                }
        }
        // Use shared container for PendingUpload, regular container for other models
        .modelContainer(sharedContainer)
    }

    /// Clear Keychain on first launch to handle reinstall edge case.
    ///
    /// iOS Keychain items are NOT deleted when an app is uninstalled.
    /// This can cause issues where a reinstalled app has stale tokens.
    /// We use UserDefaults (which IS deleted on uninstall) to detect first launch.
    private func clearKeychainOnFirstLaunch() {
        let hasLaunchedKey = "hasLaunchedBefore"

        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            // First launch - clear any stale Keychain items
            Task {
                try? await KeychainService.shared.clearTokens()
            }
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }
    }
}
