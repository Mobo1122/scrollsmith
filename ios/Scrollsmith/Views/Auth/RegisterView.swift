import SwiftUI

/// Registration view for creating a new account.
struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    let onSwitchToLogin: () -> Void

    enum Field {
        case email, password, confirmPassword
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Create account")
                    .font(.largeTitle)
                    .bold()

                Text("Sign up to get started")
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
                    HStack {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("Min 8 characters")
                            .font(.caption2)
                            .foregroundColor(password.count >= 8 ? .green : .secondary)
                    }

                    SecureField("Create a password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                }

                // Confirm password field
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !confirmPassword.isEmpty {
                            if passwordsMatch {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else {
                                Text("Passwords don't match")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            register()
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

            // Register button
            Button(action: register) {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Create Account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!isFormValid || authViewModel.isLoading)

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

            // Switch to login
            HStack {
                Text("Already have an account?")
                    .foregroundColor(.secondary)

                Button("Sign in", action: onSwitchToLogin)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .padding()
        .onAppear {
            authViewModel.clearError()
        }
    }

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var isFormValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        passwordsMatch
    }

    private func register() {
        guard isFormValid else { return }
        focusedField = nil

        Task {
            await authViewModel.register(email: email, password: password)
        }
    }
}
