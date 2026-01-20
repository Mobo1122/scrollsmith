import Foundation
import SwiftUI

/// Observable view model for authentication state.
///
/// Use this in your views to track login state and perform auth operations.
@MainActor
class AuthViewModel: ObservableObject {
    /// Current authentication state.
    @Published private(set) var authState: AuthState = .loading

    /// Current user data, if authenticated.
    @Published private(set) var currentUser: UserResponse?

    /// Error message to display, if any.
    @Published var errorMessage: String?

    /// Whether an auth operation is in progress.
    @Published private(set) var isLoading = false

    private let authService = AuthService.shared

    init() {
        Task {
            await checkAuthState()
        }
    }

    // MARK: - Auth State

    /// Check if user is authenticated and fetch their data.
    func checkAuthState() async {
        authState = .loading

        guard await authService.isAuthenticated() else {
            authState = .unauthenticated
            currentUser = nil
            return
        }

        do {
            let user = try await authService.fetchCurrentUser()
            currentUser = user
            authState = .authenticated
        } catch {
            // Token might be expired or invalid
            authState = .unauthenticated
            currentUser = nil
        }
    }

    // MARK: - Authentication Actions

    /// Register a new user.
    func register(email: String, password: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.register(email: email, password: password)
            currentUser = user
            authState = .authenticated
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Registration failed. Please try again."
        }

        isLoading = false
    }

    /// Login with email and password.
    func login(email: String, password: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.login(email: email, password: password)
            currentUser = user
            authState = .authenticated
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Login failed. Please try again."
        }

        isLoading = false
    }

    /// Logout the current user.
    func logout() async {
        guard !isLoading else { return }

        isLoading = true

        do {
            try await authService.logout()
        } catch {
            // Ignore logout errors - clear state anyway
        }

        currentUser = nil
        authState = .unauthenticated
        isLoading = false
    }

    /// Request a password reset email.
    func forgotPassword(email: String) async -> Bool {
        guard !isLoading else { return false }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.forgotPassword(email: email)
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to send reset email. Please try again."
            isLoading = false
            return false
        }
    }

    /// Resend email verification.
    func resendVerification() async -> Bool {
        guard !isLoading else { return false }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.resendVerification()
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to send verification email."
            isLoading = false
            return false
        }
    }

    /// Refresh user data from server.
    func refreshUser() async {
        do {
            let user = try await authService.fetchCurrentUser()
            currentUser = user
        } catch {
            // Silently fail - user might be offline
        }
    }

    /// Clear any error messages.
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Auth State

enum AuthState {
    case loading
    case authenticated
    case unauthenticated
}
