import SwiftUI

/// View for requesting a password reset email.
struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var showSuccessAlert = false
    @FocusState private var emailFocused: Bool

    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Reset password")
                    .font(.largeTitle)
                    .bold()

                Text("Enter your email and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 16)

            // Email field
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("you@example.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($emailFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        sendResetEmail()
                    }
            }

            // Error message
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Send button
            Button(action: sendResetEmail) {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Send Reset Link")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!isFormValid || authViewModel.isLoading)

            Spacer()

            // Back to login
            Button(action: onBack) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back to login")
                }
                .font(.subheadline)
            }
        }
        .padding()
        .onAppear {
            authViewModel.clearError()
            emailFocused = true
        }
        .alert("Check your email", isPresented: $showSuccessAlert) {
            Button("OK") {
                onBack()
            }
        } message: {
            Text("If an account exists with that email, we've sent a password reset link.")
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@")
    }

    private func sendResetEmail() {
        guard isFormValid else { return }
        emailFocused = false

        Task {
            let success = await authViewModel.forgotPassword(email: email)
            if success {
                showSuccessAlert = true
            }
        }
    }
}
