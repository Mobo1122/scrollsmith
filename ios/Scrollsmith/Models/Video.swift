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
    var playbooks: [Playbook] = []  // Many-to-many: video can belong to multiple playbooks

    @Relationship(deleteRule: .cascade)
    var habits: [Habit]?

    init(id: UUID = UUID(), user: User, sourceUrl: String? = nil, transcript: String? = nil, summaryBullets: String? = nil, tags: [String]? = nil) {
        self.id = id
        self.user = user
        self.sourceUrl = sourceUrl
        self.transcript = transcript
        self.summaryBullets = summaryBullets
        self.tags = tags
        self.createdAt = Date()
        self.playbooks = []  // Initialize empty, add playbooks separately
    }
}
