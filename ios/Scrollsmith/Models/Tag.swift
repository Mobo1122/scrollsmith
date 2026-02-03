import Foundation

/// Tag data transfer object from the backend API.
/// Represents an aggregated tag with video count.
struct TagDTO: Codable, Identifiable {
    let id: String          // Tag name as ID
    let name: String        // Display name
    let videoCount: Int     // Count of videos with this tag
    let createdAt: Date     // First appearance of tag

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case videoCount
        case createdAt
    }
}
