import SwiftUI
import SwiftData

@main
struct ScrollsmithApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [User.self, Video.self, Habit.self, Playbook.self])
    }
}
