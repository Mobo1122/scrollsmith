import Foundation

// MARK: - Summary Format

/// Summary display format options.
///
/// - bullets: Free tier bullet-point summary
/// - steps: Pro tier step-by-step checklist with timestamps
/// - cards: Pro tier swipeable cards with categorized insights
enum SummaryFormat: String, CaseIterable {
    case bullets = "Bullets"
    case steps = "Steps"
    case cards = "Cards"
}

// MARK: - Step Checklist Types

/// Step-by-step checklist summary (Pro tier).
///
/// Matches backend StepChecklist schema in summary.py.
struct StepChecklist: Codable {
    let title: String
    let steps: [StepItem]
    let estimatedDurationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case steps
        case estimatedDurationMinutes = "estimated_duration_minutes"
    }
}

/// Individual step in a checklist.
///
/// Matches backend StepChecklistItem schema in summary.py.
struct StepItem: Codable, Identifiable {
    let stepNumber: Int
    let instruction: String
    let timestampSeconds: Int?

    var id: Int { stepNumber }

    enum CodingKeys: String, CodingKey {
        case stepNumber = "step_number"
        case instruction
        case timestampSeconds = "timestamp_seconds"
    }
}

// MARK: - Cards Summary Types

/// Swipeable cards summary (Pro tier).
///
/// Matches backend CardsSummary schema in summary.py.
struct CardsSummary: Codable {
    let cards: [CardItem]
}

/// Individual swipeable card with category.
///
/// Matches backend SwipeableCard schema in summary.py.
struct CardItem: Codable, Identifiable {
    let title: String
    let content: String
    let category: CardCategory

    var id: String { title }
}

/// Card category for visual styling.
///
/// Matches backend Literal["tip", "warning", "insight", "action"].
enum CardCategory: String, Codable {
    case tip
    case warning
    case insight
    case action
}
