import Foundation
import SwiftData

/// Provides a shared SwiftData model container for use by both
/// the main app and the Share Extension.
///
/// Uses an App Group to store data in a location accessible to both targets.
/// This allows the Share Extension to create PendingUpload records that
/// the main app can read and process.
enum SharedModelContainer {

    /// The App Group identifier. Must match the App Group configured in
    /// both the main app and Share Extension capabilities.
    static let appGroupIdentifier = "group.com.scrollsmith.shared"

    /// Schema containing only models that need to be shared.
    /// Keep this minimal to avoid issues with extension memory limits.
    private static let sharedSchema = Schema([
        PendingUpload.self
    ])

    /// The shared model container instance.
    ///
    /// Uses a shared App Group container so both the main app
    /// and Share Extension can access the same data.
    static let shared: ModelContainer = {
        let config = ModelConfiguration(
            schema: sharedSchema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroupIdentifier)
        )

        do {
            return try ModelContainer(for: sharedSchema, configurations: [config])
        } catch {
            // This should not happen in production
            fatalError("Failed to create shared model container: \(error)")
        }
    }()

    /// Creates a model context for the shared container.
    /// Use this when you need a new context (e.g., in background tasks).
    static func createContext() -> ModelContext {
        ModelContext(shared)
    }
}
