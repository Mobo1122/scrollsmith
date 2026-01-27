import Foundation
import Sentry

/// Crash reporting service using Sentry SDK.
///
/// Provides centralized crash reporting and error tracking.
/// Sentry is preferred over Firebase Crashlytics because it
/// explicitly supports SwiftUI.
final class CrashReportingService {
    static let shared = CrashReportingService()

    private var isConfigured = false

    private init() {}

    /// Configure Sentry SDK.
    ///
    /// Call this once at app launch, before any other code runs.
    /// Safe to call multiple times (subsequent calls are no-ops).
    func configure() {
        guard !isConfigured else { return }

        // Skip if no DSN configured
        guard !Configuration.sentryDSN.isEmpty else {
            print("CrashReporting: Sentry DSN not configured, skipping")
            return
        }

        SentrySDK.start { options in
            options.dsn = Configuration.sentryDSN
            options.environment = Configuration.environment
            options.releaseName = "scrollsmith-ios@\(Configuration.appVersion)+\(Configuration.buildNumber)"

            // Enable debug mode in development
            options.debug = Configuration.isDebug

            // Performance monitoring (20% sample rate)
            options.tracesSampleRate = 0.2

            // Attach screenshots to crash reports (helps debugging UI issues)
            options.attachScreenshot = true

            // Attach view hierarchy (helps debugging SwiftUI issues)
            options.attachViewHierarchy = true

            // Don't send PII by default
            options.sendDefaultPii = false

            // Enable automatic session tracking
            options.enableAutoSessionTracking = true
        }

        isConfigured = true
        print("CrashReporting: Sentry initialized for \(Configuration.environment)")
    }

    /// Set user context for error tracking.
    ///
    /// Call this when user logs in to associate crashes with users.
    /// - Parameter userId: The user's UUID, or nil to clear user context.
    func setUser(userId: UUID?) {
        guard isConfigured else { return }

        if let userId = userId {
            let user = User(userId: userId.uuidString)
            SentrySDK.setUser(user)
        } else {
            SentrySDK.setUser(nil)
        }
    }

    /// Capture a non-fatal error.
    ///
    /// Use for errors that don't crash the app but should be tracked.
    /// - Parameters:
    ///   - error: The error to capture
    ///   - context: Additional context dictionary
    func captureError(_ error: Error, context: [String: Any]? = nil) {
        guard isConfigured else { return }

        SentrySDK.capture(error: error) { scope in
            if let context = context {
                scope.setContext(value: context, key: "custom")
            }
        }
    }

    /// Capture a message (for logging important events).
    ///
    /// - Parameter message: The message to capture
    func captureMessage(_ message: String) {
        guard isConfigured else { return }
        SentrySDK.capture(message: message)
    }

    /// Add a breadcrumb for debugging.
    ///
    /// Breadcrumbs appear in crash reports to show what happened before the crash.
    /// - Parameters:
    ///   - category: Category (e.g., "navigation", "api", "user")
    ///   - message: Description of what happened
    func addBreadcrumb(category: String, message: String) {
        guard isConfigured else { return }

        let crumb = Breadcrumb()
        crumb.category = category
        crumb.message = message
        crumb.level = .info
        SentrySDK.addBreadcrumb(crumb)
    }
}
