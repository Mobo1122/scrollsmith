import Foundation
import Mixpanel

/// Centralized analytics service using Mixpanel.
///
/// Tracks key metrics per phase success criteria:
/// - Video views
/// - Habit completions
/// - Free -> Pro conversions
/// - User retention (via identify)
actor AnalyticsService {
    static let shared = AnalyticsService()

    private var isConfigured = false

    private init() {}

    /// Configure Mixpanel SDK.
    func configure() {
        guard !isConfigured else { return }

        // Skip if no token configured
        guard !Configuration.mixpanelToken.isEmpty else {
            print("Analytics: Mixpanel token not configured, skipping")
            return
        }

        Mixpanel.initialize(
            token: Configuration.mixpanelToken,
            trackAutomaticEvents: false  // We track specific events only
        )

        isConfigured = true
        print("Analytics: Mixpanel initialized")
    }

    // MARK: - User Identification

    func identifyUser(userId: UUID, isPro: Bool) {
        guard isConfigured else { return }

        Mixpanel.mainInstance().identify(distinctId: userId.uuidString)
        Mixpanel.mainInstance().people.set(properties: [
            "is_pro": isPro,
            "platform": "ios",
            "app_version": Configuration.appVersion,
        ])
    }

    func resetUser() {
        guard isConfigured else { return }
        Mixpanel.mainInstance().reset()
    }

    func updateProStatus(isPro: Bool) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().people.set(properties: [
            "is_pro": isPro,
        ])
    }

    // MARK: - Key Events

    func trackVideoView(videoId: UUID) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().track(event: "video_viewed", properties: [
            "video_id": videoId.uuidString,
        ])
    }

    func trackHabitCompletion(habitId: UUID, streakLength: Int) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().track(event: "habit_completed", properties: [
            "habit_id": habitId.uuidString,
            "streak_length": streakLength,
        ])
    }

    func trackProConversion(source: String) {
        guard isConfigured else { return }

        Mixpanel.mainInstance().track(event: "pro_conversion", properties: [
            "source": source,
        ])

        Mixpanel.mainInstance().people.set(properties: [
            "is_pro": true,
            "converted_at": ISO8601DateFormatter().string(from: Date()),
        ])
    }

    func trackPaywallShown(source: String) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().track(event: "paywall_shown", properties: [
            "source": source,
        ])
    }

    func trackPaywallDismissed(source: String) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().track(event: "paywall_dismissed", properties: [
            "source": source,
        ])
    }

    func trackScreen(_ screenName: String) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().track(event: "screen_viewed", properties: [
            "screen_name": screenName,
        ])
    }
}
