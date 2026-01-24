import SwiftUI

/// Main tab bar view for authenticated users.
///
/// Provides navigation between Home, Capture, and Settings tabs.
struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var uploadQueueService: UploadQueueService

    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "Home"
        case capture = "Capture"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home:
                return "house"
            case .capture:
                return "plus.circle.fill"
            case .settings:
                return "gearshape"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            CaptureView()
                .tabItem {
                    Label(Tab.capture.rawValue, systemImage: Tab.capture.icon)
                }
                .tag(Tab.capture)
                .badge(uploadQueueService.pendingCount)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
    }
}

// SettingsView is now in Views/Settings/SettingsView.swift

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionViewModel())
        .environmentObject(UploadQueueService.shared)
}
