import Foundation

// MARK: - Frequency Enum

/// Habit frequency options matching backend enum values.
enum HabitFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case threeTimesWeekly = "3x_weekly"
    case weekly = "weekly"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .threeTimesWeekly: return "3x Weekly"
        case .weekly: return "Weekly"
        }
    }

    var timesPerWeek: Int {
        switch self {
        case .daily: return 7
        case .threeTimesWeekly: return 3
        case .weekly: return 1
        }
    }

    var description: String {
        switch self {
        case .daily: return "Every day"
        case .threeTimesWeekly: return "3 times per week"
        case .weekly: return "Once per week"
        }
    }
}

// MARK: - Habit Suggestion (from extraction)

/// A single habit suggestion returned by Claude API.
struct HabitSuggestion: Codable, Identifiable {
    let title: String
    let description: String
    let suggestedFrequency: HabitFrequency

    // Identifiable conformance for SwiftUI List
    var id: String { title }

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case suggestedFrequency = "suggested_frequency"
    }
}

// MARK: - Extraction Response

/// Response from POST /habits/videos/{id}/extract endpoint.
struct HabitExtractionResponse: Codable {
    let videoId: UUID
    let suggestions: [HabitSuggestion]

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case suggestions
    }
}

// MARK: - Habit DTO (full habit from backend)

/// Full habit object from backend (for list/detail views).
struct HabitDTO: Codable, Identifiable {
    let id: UUID
    let videoId: UUID?
    let title: String
    let frequency: String
    let currentStreak: Int
    let longestStreak: Int
    let reminderTime: String?  // "HH:MM:SS" format from backend
    let reminderDays: [Int]?
    let isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case videoId = "video_id"
        case title
        case frequency
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case reminderTime = "reminder_time"
        case reminderDays = "reminder_days"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    /// Parsed frequency as enum (falls back to daily if unknown).
    var frequencyEnum: HabitFrequency {
        HabitFrequency(rawValue: frequency) ?? .daily
    }

    /// Parse reminderTime string into DateComponents (hour, minute).
    var reminderTimeComponents: DateComponents? {
        guard let timeString = reminderTime else { return nil }
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return DateComponents(hour: hour, minute: minute)
    }
}

// MARK: - Create Request

/// Request body for POST /habits endpoint.
struct HabitCreateRequest: Codable {
    let videoId: UUID
    let title: String
    let frequency: String

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case title
        case frequency
    }

    init(videoId: UUID, title: String, frequency: HabitFrequency) {
        self.videoId = videoId
        self.title = title
        self.frequency = frequency.rawValue
    }
}

// MARK: - Selection State (for UI)

/// Tracks selection state and frequency override for a habit suggestion.
struct HabitSelectionState: Identifiable {
    let suggestion: HabitSuggestion
    var isSelected: Bool
    var frequency: HabitFrequency

    var id: String { suggestion.id }

    init(suggestion: HabitSuggestion, isSelected: Bool = true) {
        self.suggestion = suggestion
        self.isSelected = isSelected
        self.frequency = suggestion.suggestedFrequency
    }
}

// MARK: - Update Request

/// Request body for PATCH /habits/{id} endpoint.
struct HabitUpdateRequest: Codable {
    var title: String?
    var frequency: String?
    var reminderTime: String?  // "HH:MM" format
    var reminderDays: [Int]?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case title
        case frequency
        case reminderTime = "reminder_time"
        case reminderDays = "reminder_days"
        case isActive = "is_active"
    }
}

// MARK: - Completion Request/Response

/// Request body for POST /habits/{id}/complete endpoint.
struct HabitCompletionRequest: Codable {
    let userTimezone: String

    enum CodingKeys: String, CodingKey {
        case userTimezone = "user_timezone"
    }

    init(timezone: String = TimeZone.current.identifier) {
        self.userTimezone = timezone
    }
}

/// Response from POST /habits/{id}/complete endpoint.
struct HabitCompletionResponse: Codable {
    let id: UUID
    let habitId: UUID
    let completedAt: Date
    let currentStreak: Int
    let longestStreak: Int

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case completedAt = "completed_at"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
    }
}
