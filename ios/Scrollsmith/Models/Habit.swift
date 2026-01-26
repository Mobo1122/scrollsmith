import Foundation
import SwiftData

@Model
class Habit {
    @Attribute(.unique) var id: UUID
    var title: String
    var frequency: String
    var currentStreak: Int
    var longestStreak: Int
    var createdAt: Date

    // Reminder configuration
    var reminderTime: Date?  // Only time component used
    var reminderDays: [Int]? // 1=Sun through 7=Sat, nil for daily
    var isActive: Bool
    var videoId: UUID?

    var user: User?
    var video: Video?

    init(
        id: UUID = UUID(),
        user: User,
        video: Video? = nil,
        title: String,
        frequency: String = "daily",
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        reminderTime: Date? = nil,
        reminderDays: [Int]? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.user = user
        self.video = video
        self.videoId = video?.id
        self.title = title
        self.frequency = frequency
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.reminderTime = reminderTime
        self.reminderDays = reminderDays
        self.isActive = isActive
        self.createdAt = Date()
    }
}
