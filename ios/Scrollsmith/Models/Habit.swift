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

    var user: User?
    var video: Video?

    init(id: UUID = UUID(), user: User, video: Video? = nil, title: String, frequency: String = "daily", currentStreak: Int = 0, longestStreak: Int = 0) {
        self.id = id
        self.user = user
        self.video = video
        self.title = title
        self.frequency = frequency
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.createdAt = Date()
    }
}
