import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var id: UUID
    var email: String
    var appleId: String?
    var subscriptionTier: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Playbook.user)
    var playbooks: [Playbook]?

    @Relationship(deleteRule: .cascade, inverse: \Video.user)
    var videos: [Video]?

    @Relationship(deleteRule: .cascade, inverse: \Habit.user)
    var habits: [Habit]?

    init(id: UUID = UUID(), email: String, appleId: String? = nil, subscriptionTier: String = "free") {
        self.id = id
        self.email = email
        self.appleId = appleId
        self.subscriptionTier = subscriptionTier
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
