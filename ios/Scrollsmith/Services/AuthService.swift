import Foundation

/// Service for authentication operations.
///
/// Handles login, registration, token refresh, and logout.
/// Stores tokens securely in the Keychain.
actor AuthService {
    static let shared = AuthService()

    private let baseURL = "https://backend-production-d73a.up.railway.app"
    private let session = URLSession.shared
    private let keychain = KeychainService.shared

    private init() {}

    // MARK: - Authentication

    /// Register a new user with email and password.
    func register(email: String, password: String) async throws -> UserResponse {
        let url = URL(string: "\(baseURL)/api/v1/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)
        try await keychain.saveTokens(tokens)

        return try await fetchCurrentUser()
    }

    /// Login with email and password.
    func login(email: String, password: String) async throws -> UserResponse {
        let url = URL(string: "\(baseURL)/api/v1/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // OAuth2 form expects 'username' field even for email
        let body = "username=\(email.urlEncoded)&password=\(password.urlEncoded)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)
        try await keychain.saveTokens(tokens)

        return try await fetchCurrentUser()
    }

    /// Sign in with Apple.
    ///
    /// Sends the Apple identity token to the backend for verification.
    /// The backend will create a new user or return the existing one.
    func signInWithApple(identityToken: String, email: String?, fullName: String?) async throws -> UserResponse {
        let url = URL(string: "\(baseURL)/api/v1/auth/apple")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["identity_token": identityToken]
        if let email = email {
            body["email"] = email
        }
        if let fullName = fullName {
            body["full_name"] = fullName
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)
        try await keychain.saveTokens(tokens)

        return try await fetchCurrentUser()
    }

    /// Logout the current user.
    func logout() async throws {
        // Revoke refresh token on server
        if let refreshToken = await keychain.getRefreshToken() {
            let url = URL(string: "\(baseURL)/api/v1/auth/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["refresh_token": refreshToken]
            request.httpBody = try JSONEncoder().encode(body)

            // Fire and forget - we clear local tokens regardless
            _ = try? await session.data(for: request)
        }

        // Clear local tokens
        try await keychain.clearTokens()
    }

    /// Refresh the access token using the refresh token.
    func refreshTokens() async throws {
        guard let refreshToken = await keychain.getRefreshToken() else {
            throw AuthError.noRefreshToken
        }

        let url = URL(string: "\(baseURL)/api/v1/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        // If refresh fails, clear tokens (session expired)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            try await keychain.clearTokens()
            throw AuthError.sessionExpired
        }

        let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)
        try await keychain.saveTokens(tokens)
    }

    // MARK: - User Data

    /// Fetch the current authenticated user's profile.
    func fetchCurrentUser() async throws -> UserResponse {
        guard let accessToken = await keychain.getAccessToken() else {
            throw AuthError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/api/v1/auth/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        // Handle 401 by attempting token refresh
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            try await refreshTokens()
            return try await fetchCurrentUser()
        }

        try validateResponse(response)
        return try JSONDecoder.apiDecoder.decode(UserResponse.self, from: data)
    }

    /// Check if the user is currently authenticated (has valid tokens).
    func isAuthenticated() async -> Bool {
        await keychain.hasTokens()
    }

    /// Get the current access token for making authenticated API requests.
    func getAccessToken() async -> String? {
        await keychain.getAccessToken()
    }

    // MARK: - Password Reset

    /// Request a password reset email.
    func forgotPassword(email: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/auth/forgot-password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Email Verification

    /// Resend the email verification link.
    func resendVerification() async throws {
        guard let accessToken = await keychain.getAccessToken() else {
            throw AuthError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/api/v1/auth/resend-verification")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw AuthError.badRequest
        case 401:
            throw AuthError.invalidCredentials
        case 409:
            throw AuthError.emailAlreadyRegistered
        default:
            throw AuthError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case noRefreshToken
    case sessionExpired
    case invalidCredentials
    case emailAlreadyRegistered
    case badRequest
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .noRefreshToken:
            return "No refresh token available"
        case .sessionExpired:
            return "Session expired. Please log in again."
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyRegistered:
            return "This email is already registered"
        case .badRequest:
            return "Invalid request"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error (\(code))"
        }
    }
}

// MARK: - String Extension

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

// MARK: - JSONDecoder Extension

extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        .flexibleAPIDecoder()
    }
}
