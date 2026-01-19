import Foundation
import SwiftData

@Model
class Video {
    @Attribute(.unique) var id: UUID
    var sourceUrl: String?
    var transcript: String?
    var summaryBullets: String?
    var tags: [String]?
    var createdAt: Date

    var user: User?
    var playbook: Playbook?

    @Relationship(deleteRule: .cascade)
    var habits: [Habit]?

    init(id: UUID = UUID(), user: User, playbook: Playbook? = nil, sourceUrl: String? = nil, transcript: String? = nil, summaryBullets: String? = nil, tags: [String]? = nil) {
        self.id = id
        self.user = user
        self.playbook = playbook
        self.sourceUrl = sourceUrl
        self.transcript = transcript
        self.summaryBullets = summaryBullets
        self.tags = tags
        self.createdAt = Date()
    }
}
