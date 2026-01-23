import Foundation
import SwiftData

@Model
class Playbook {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String?
    var isSystem: Bool = false  // True for Favorites playbook (cannot be deleted)
    var createdAt: Date
    var updatedAt: Date  // For sorting by recent activity

    var user: User?

    @Relationship(inverse: \Video.playbooks)
    var videos: [Video] = []  // Many-to-many: playbook can contain multiple videos

    init(id: UUID = UUID(), user: User, name: String, icon: String? = nil, isSystem: Bool = false) {
        self.id = id
        self.user = user
        self.name = name
        self.icon = icon
        self.isSystem = isSystem
        self.createdAt = Date()
        self.updatedAt = Date()
        self.videos = []  // Initialize empty
    }
}
