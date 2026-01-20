import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .loading:
                // Show loading while checking auth state
                ProgressView("Loading...")

            case .unauthenticated:
                // Show login/register screens
                AuthContainerView()

            case .authenticated:
                // Show main app content
                HomeView()
            }
        }
    }
}

/// Main app home view shown after authentication.
struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var healthStatus: String = "Not checked"
    @State private var isCheckingHealth: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // User info
                if let user = authViewModel.currentUser {
                    VStack(spacing: 4) {
                        Text("Welcome!")
                            .font(.title2)
                            .bold()

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if !user.emailVerified {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Email not verified")
                                    .font(.caption)
                            }
                            .padding(.top, 8)

                            Button("Resend verification email") {
                                Task {
                                    await authViewModel.resendVerification()
                                }
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                Divider()

                // Backend health check (for testing)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Backend Health:")
                        .font(.headline)

                    Text(healthStatus)
                        .foregroundColor(healthStatus.contains("healthy") ? .green : .primary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }

                Button(action: {
                    Task {
                        await checkHealth()
                    }
                }) {
                    HStack {
                        if isCheckingHealth {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Check Backend Health")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isCheckingHealth)

                Spacer()
            }
            .padding()
            .navigationTitle("Scrollsmith")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        Task {
                            await authViewModel.logout()
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func checkHealth() async {
        isCheckingHealth = true
        healthStatus = "Checking..."

        do {
            let response = try await APIClient.shared.healthCheck()
            healthStatus = "✓ Status: \(response.status)\n✓ Database: \(response.database)"
        } catch {
            healthStatus = "✗ Error: \(error.localizedDescription)"
        }

        isCheckingHealth = false
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
