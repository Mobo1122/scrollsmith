import SwiftUI
import SwiftData

@main
struct ScrollsmithApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        // Clear stale Keychain items on first launch after reinstall
        // Keychain items persist after app uninstall, which can cause issues
        clearKeychainOnFirstLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
        .modelContainer(for: [User.self, Video.self, Habit.self, Playbook.self])
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
