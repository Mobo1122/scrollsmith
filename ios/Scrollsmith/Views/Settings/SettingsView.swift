import SwiftUI

/// Settings and account management view.
///
/// Displays:
/// - User email and account info
/// - Subscription status
/// - Upgrade to Pro button (free tier)
/// - Restore purchases button
/// - Logout button
struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    @State private var isRestoringPurchases = false
    @State private var restoreError: String?
    @State private var showRestoreSuccess = false

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    if let user = authViewModel.currentUser {
                        LabeledContent("Email", value: user.email)

                        LabeledContent("Status") {
                            Text(subscriptionViewModel.isPro ? "Pro" : "Free")
                                .foregroundColor(subscriptionViewModel.isPro ? Theme.accent : Theme.Text.secondary)
                                .fontWeight(.medium)
                        }
                    }
                }

                // Subscription Section
                Section("Subscription") {
                    if subscriptionViewModel.isPro {
                        Label("You have Scrollsmith Pro", systemImage: "crown.fill")
                            .foregroundColor(Theme.accent)
                    } else {
                        Button {
                            subscriptionViewModel.showPaywall = true
                        } label: {
                            Label("Upgrade to Pro", systemImage: "arrow.up.circle.fill")
                        }
                        .tint(Theme.accent)

                        LabeledContent("Videos this month") {
                            Text("\(subscriptionViewModel.videosUsed) / \(subscriptionViewModel.videosLimit)")
                                .foregroundColor(subscriptionViewModel.isNearLimit ? Theme.Semantic.warning : Theme.Text.secondary)
                        }
                    }

                    Button {
                        Task {
                            await restorePurchases()
                        }
                    } label: {
                        if isRestoringPurchases {
                            HStack {
                                Text("Restore Purchases")
                                Spacer()
                                ProgressView()
                                    .tint(Theme.accent)
                            }
                        } else {
                            Text("Restore Purchases")
                        }
                    }
                    .disabled(isRestoringPurchases)

                    if let error = restoreError {
                        Text(error)
                            .font(Typography.footnote)
                            .foregroundColor(Theme.Semantic.error)
                    }
                }

                // About Section
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Scrollsmith", systemImage: "info.circle")
                    }
                }

                // Account Actions
                Section {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.logout()
                        }
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(Typography.title3)
                }
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK") { }
            } message: {
                Text(subscriptionViewModel.isPro ?
                     "Your Pro subscription has been restored." :
                     "No previous purchases found.")
            }
        }
    }

    // MARK: - Actions

    private func restorePurchases() async {
        isRestoringPurchases = true
        restoreError = nil

        print("🔄 Starting restore purchases...")

        do {
            let isPro = try await SubscriptionService.shared.restorePurchases()
            print("🔄 Restore completed, isPro: \(isPro)")
            await subscriptionViewModel.refresh()
            showRestoreSuccess = true
        } catch {
            print("🔄 Restore failed: \(error)")
            restoreError = "Failed to restore: \(error.localizedDescription)"
        }

        isRestoringPurchases = false
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionViewModel())
}
