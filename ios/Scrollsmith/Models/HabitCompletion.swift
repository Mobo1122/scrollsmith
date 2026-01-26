import Foundation
import SwiftData

/// Local record of a habit completion for offline-first UX.
/// Synced with backend via POST /habits/{id}/complete.
@Model
class HabitCompletion {
    @Attribute(.unique) var id: UUID
    var habitId: UUID
    var completedAt: Date
    var userTimezone: String
    var syncedToBackend: Bool

    init(
        id: UUID = UUID(),
        habitId: UUID,
        completedAt: Date = Date(),
        userTimezone: String = TimeZone.current.identifier,
        syncedToBackend: Bool = false
    ) {
        self.id = id
        self.habitId = habitId
        self.completedAt = completedAt
        self.userTimezone = userTimezone
        self.syncedToBackend = syncedToBackend
    }
}
