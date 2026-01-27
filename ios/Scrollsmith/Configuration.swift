import Foundation

/// Centralized configuration for external services.
/// Add to .gitignore if storing sensitive keys locally.
enum Configuration {
    // MARK: - API

    static let apiBaseURL = "https://backend-production-d73a.up.railway.app"

    // MARK: - Sentry (Crash Reporting)

    static let sentryDSN = "https://ad9e68faa892abb38d9648c8d6ee0b99@o4510782914691072.ingest.de.sentry.io/4510783049760848"

    // MARK: - Mixpanel (Analytics)

    static let mixpanelToken = "01482dcec18184f1573a16f6b52cf175"

    // MARK: - Environment

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var environment: String {
        isDebug ? "development" : "production"
    }
}
