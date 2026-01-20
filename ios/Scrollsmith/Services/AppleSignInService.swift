import AuthenticationServices
import Foundation

/// Service for handling Apple Sign In authentication flow.
///
/// Implements ASAuthorizationControllerDelegate to handle Apple Sign In responses.
/// Caches email and name from first authorization (Apple only provides these once).
class AppleSignInService: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    static let shared = AppleSignInService()

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    // Cache keys for email and name (Apple only provides on first auth)
    private let cachedEmailKey = "apple_signin_cached_email"
    private let cachedNameKey = "apple_signin_cached_name"

    private override init() {
        super.init()
    }

    /// Start the Apple Sign In flow.
    ///
    /// Returns the identity token and user information from Apple.
    /// Email and name are only available on first authorization.
    func signIn() async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// Check if the Apple Sign In credential is still valid.
    func checkCredentialState(appleUserId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserId) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AppleSignInError.invalidCredential)
            continuation = nil
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
            continuation = nil
            return
        }

        let userIdentifier = appleIDCredential.user

        // Email and full name are only provided on first authorization
        // Cache them for future use
        var email = appleIDCredential.email
        var fullName: String? = nil

        if let familyName = appleIDCredential.fullName?.familyName,
           let givenName = appleIDCredential.fullName?.givenName {
            fullName = "\(givenName) \(familyName)"
            // Cache the name
            UserDefaults.standard.set(fullName, forKey: cachedNameKey + userIdentifier)
        }

        if let email = email {
            // Cache the email
            UserDefaults.standard.set(email, forKey: cachedEmailKey + userIdentifier)
        } else {
            // Try to retrieve cached email
            email = UserDefaults.standard.string(forKey: cachedEmailKey + userIdentifier)
        }

        // Retrieve cached name if not provided
        if fullName == nil {
            fullName = UserDefaults.standard.string(forKey: cachedNameKey + userIdentifier)
        }

        let result = AppleSignInResult(
            identityToken: identityToken,
            userIdentifier: userIdentifier,
            email: email,
            fullName: fullName
        )

        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                continuation?.resume(throwing: AppleSignInError.canceled)
            case .failed:
                continuation?.resume(throwing: AppleSignInError.failed)
            case .invalidResponse:
                continuation?.resume(throwing: AppleSignInError.invalidResponse)
            case .notHandled:
                continuation?.resume(throwing: AppleSignInError.notHandled)
            case .unknown:
                continuation?.resume(throwing: AppleSignInError.unknown)
            case .notInteractive:
                continuation?.resume(throwing: AppleSignInError.notInteractive)
            @unknown default:
                continuation?.resume(throwing: AppleSignInError.unknown)
            }
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window for presenting the Apple Sign In sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign In")
        }
        return window
    }
}

// MARK: - Result Types

/// Result from Apple Sign In containing the identity token and user information.
struct AppleSignInResult {
    /// The JWT identity token to send to the backend for verification.
    let identityToken: String

    /// Apple's unique, stable identifier for the user.
    let userIdentifier: String

    /// User's email (only provided on first authorization, then cached).
    let email: String?

    /// User's full name (only provided on first authorization, then cached).
    let fullName: String?
}

// MARK: - Errors

enum AppleSignInError: LocalizedError {
    case canceled
    case failed
    case invalidResponse
    case notHandled
    case notInteractive
    case unknown
    case invalidCredential
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .canceled:
            return "Sign in was canceled"
        case .failed:
            return "Sign in failed"
        case .invalidResponse:
            return "Invalid response from Apple"
        case .notHandled:
            return "Sign in request not handled"
        case .notInteractive:
            return "Sign in requires user interaction"
        case .unknown:
            return "An unknown error occurred"
        case .invalidCredential:
            return "Invalid Apple credential"
        case .missingIdentityToken:
            return "Missing identity token from Apple"
        }
    }
}
