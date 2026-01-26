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
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case videoId = "video_id"
        case title
        case frequency
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case createdAt = "created_at"
    }

    /// Parsed frequency as enum (falls back to daily if unknown).
    var frequencyEnum: HabitFrequency {
        HabitFrequency(rawValue: frequency) ?? .daily
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
