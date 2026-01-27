import SwiftUI

/// User-friendly error types for display.
///
/// Converts API and system errors into actionable messages
/// that users can understand and act on.
enum AppError: LocalizedError, Equatable {
    /// Network connectivity issue
    case network(underlying: String)

    /// Server returned an error
    case serverError(statusCode: Int)

    /// No internet connection
    case noInternet

    /// Authentication required (token expired/invalid)
    case unauthorized

    /// Feature requires Pro subscription
    case proRequired

    /// Request timed out
    case timeout

    /// Unknown error with message
    case unknown(message: String)

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        switch self {
        case .network:
            return "Unable to connect to server"
        case .serverError(let code):
            return "Something went wrong (Error \(code))"
        case .noInternet:
            return "No internet connection"
        case .unauthorized:
            return "Please log in again"
        case .proRequired:
            return "This feature requires Pro"
        case .timeout:
            return "Request timed out"
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .network, .serverError, .timeout:
            return "Please try again"
        case .noInternet:
            return "Check your connection and try again"
        case .unauthorized:
            return "Tap to log in"
        case .proRequired:
            return "Upgrade to Pro to unlock"
        case .unknown:
            return nil
        }
    }

    /// Whether this error can be retried.
    var isRetryable: Bool {
        switch self {
        case .network, .serverError, .noInternet, .timeout:
            return true
        default:
            return false
        }
    }

    /// Whether this error should show the paywall.
    var showsPaywall: Bool {
        switch self {
        case .proRequired:
            return true
        default:
            return false
        }
    }

    // MARK: - Equatable (for state comparison)

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.network(let l), .network(let r)):
            return l == r
        case (.serverError(let l), .serverError(let r)):
            return l == r
        case (.noInternet, .noInternet):
            return true
        case (.unauthorized, .unauthorized):
            return true
        case (.proRequired, .proRequired):
            return true
        case (.timeout, .timeout):
            return true
        case (.unknown(let l), .unknown(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - API Error Conversion

extension AppError {
    /// Convert APIError to user-friendly AppError.
    ///
    /// - Parameter apiError: The API error to convert
    /// - Returns: User-friendly AppError
    static func from(_ apiError: APIError) -> AppError {
        switch apiError {
        case .invalidURL:
            return .unknown(message: "Invalid request")
        case .invalidResponse:
            return .unknown(message: "Invalid response from server")
        case .httpError(let statusCode):
            switch statusCode {
            case 401:
                return .unauthorized
            case 403:
                return .proRequired
            case 408, 504:
                return .timeout
            case 500...599:
                return .serverError(statusCode: statusCode)
            default:
                return .serverError(statusCode: statusCode)
            }
        case .decodingError:
            return .unknown(message: "Failed to process response")
        case .unauthorized:
            return .unauthorized
        case .proRequired:
            return .proRequired
        }
    }

    /// Convert any Error to AppError.
    ///
    /// - Parameter error: The error to convert
    /// - Returns: User-friendly AppError
    static func from(_ error: Error) -> AppError {
        if let apiError = error as? APIError {
            return from(apiError)
        }

        let nsError = error as NSError

        // Check for network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost:
                return .noInternet
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed:
                return .network(underlying: "Server unreachable")
            default:
                return .network(underlying: nsError.localizedDescription)
            }
        }

        return .unknown(message: error.localizedDescription)
    }
}

// MARK: - Error Alert View Modifier

/// View modifier for consistent error alerts.
///
/// Shows user-friendly error messages with retry option for recoverable errors.
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?
    var retryAction: (() -> Void)?
    var showPaywallAction: (() -> Void)?

    func body(content: Content) -> some View {
        content.alert(
            "Error",
            isPresented: Binding(
                get: { error != nil && !(error?.showsPaywall ?? false) },
                set: { if !$0 { error = nil } }
            ),
            presenting: error
        ) { presentedError in
            if presentedError.isRetryable, let retry = retryAction {
                Button("Retry", action: retry)
            }
            Button("OK", role: .cancel) {}
        } message: { presentedError in
            VStack {
                Text(presentedError.localizedDescription)
                if let suggestion = presentedError.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                }
            }
        }
        .onChange(of: error) { _, newError in
            // Automatically show paywall for Pro-required errors
            if let error = newError, error.showsPaywall {
                showPaywallAction?()
                self.error = nil  // Clear the error
            }
        }
    }
}

extension View {
    /// Add error alert handling to a view.
    ///
    /// - Parameters:
    ///   - error: Binding to the current error (nil = no error)
    ///   - retryAction: Optional action to retry on recoverable errors
    ///   - showPaywallAction: Optional action to show paywall on Pro-required errors
    /// - Returns: View with error alert modifier
    func errorAlert(
        _ error: Binding<AppError?>,
        retryAction: (() -> Void)? = nil,
        showPaywallAction: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(
            error: error,
            retryAction: retryAction,
            showPaywallAction: showPaywallAction
        ))
    }
}
