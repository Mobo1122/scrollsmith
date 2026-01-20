import SwiftUI

/// Login view for email/password authentication.
struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    let onSwitchToRegister: () -> Void
    let onForgotPassword: () -> Void

    enum Field {
        case email, password
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Welcome back")
                    .font(.largeTitle)
                    .bold()

                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)

            // Form
            VStack(spacing: 16) {
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
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                }

                // Password field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            login()
                        }
                }
            }

            // Error message
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Login button
            Button(action: login) {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!isFormValid || authViewModel.isLoading)

            // Forgot password
            Button(action: onForgotPassword) {
                Text("Forgot password?")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            // Divider with "or"
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)

                Text("or")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)

            // Apple Sign In
            AppleSignInButton()

            Spacer()

            // Switch to register
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.secondary)

                Button("Sign up", action: onSwitchToRegister)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .padding()
        .onAppear {
            authViewModel.clearError()
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && !password.isEmpty
    }

    private func login() {
        guard isFormValid else { return }
        focusedField = nil

        Task {
            await authViewModel.login(email: email, password: password)
        }
    }
}
