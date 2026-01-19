import Foundation
import SwiftData

@Model
class Playbook {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String?
    var createdAt: Date

    var user: User?

    @Relationship(deleteRule: .cascade)
    var videos: [Video]?

    init(id: UUID = UUID(), user: User, name: String, icon: String? = nil) {
        self.id = id
        self.user = user
        self.name = name
        self.icon = icon
        self.createdAt = Date()
    }
}
