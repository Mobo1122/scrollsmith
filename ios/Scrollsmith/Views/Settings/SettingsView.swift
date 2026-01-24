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
                                .foregroundColor(subscriptionViewModel.isPro ? .yellow : .secondary)
                                .fontWeight(.medium)
                        }
                    }
                }

                // Subscription Section
                Section("Subscription") {
                    if subscriptionViewModel.isPro {
                        Label("You have Scrollsmith Pro", systemImage: "crown.fill")
                            .foregroundColor(.yellow)
                    } else {
                        Button {
                            subscriptionViewModel.showPaywall = true
                        } label: {
                            Label("Upgrade to Pro", systemImage: "arrow.up.circle.fill")
                        }

                        LabeledContent("Videos this month") {
                            Text("\(subscriptionViewModel.videosUsed) / \(subscriptionViewModel.videosLimit)")
                                .foregroundColor(subscriptionViewModel.isNearLimit ? .orange : .secondary)
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
                            }
                        } else {
                            Text("Restore Purchases")
                        }
                    }
                    .disabled(isRestoringPurchases)

                    if let error = restoreError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
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
            .navigationTitle("Settings")
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

        do {
            _ = try await SubscriptionService.shared.restorePurchases()
            await subscriptionViewModel.refresh()
            showRestoreSuccess = true
        } catch {
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
