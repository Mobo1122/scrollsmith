import Foundation

/// User data returned from the API.
///
/// This is separate from the SwiftData User model as it represents
/// the API response format, not the local database schema.
struct UserResponse: Codable, Identifiable {
    let id: UUID
    let email: String
    let emailVerified: Bool
    let subscriptionTier: String
    let createdAt: Date
    let updatedAt: Date
}
