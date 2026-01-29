import SwiftUI

/// Sidebar content view with grouped sections for navigation.
///
/// CRITICAL: Uses `List(selection:)` binding for navigation to work.
/// This is the #1 pitfall from research - navigation breaks without it.
struct SidebarView: View {
    // MARK: - Properties

    /// Binding to the currently selected sidebar section.
    /// MUST be bound to List for navigation to work.
    @Binding var selection: SidebarSection?

    // MARK: - State

    /// Controls display of settings sheet.
    @State private var showSettings = false

    /// Controls display of capture fullScreenCover.
    @State private var showCapture = false

    // MARK: - Environment

    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @EnvironmentObject private var uploadQueueService: UploadQueueService
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        // CRITICAL: List MUST use selection binding
        List(selection: $selection) {
            // Library section
            Section("Library") {
                Label("All Videos", systemImage: SidebarSection.library.icon)
                    .tag(SidebarSection.library)
            }

            // Organization section
            Section("Organization") {
                Label("Playbooks", systemImage: SidebarSection.playbooks.icon)
                    .tag(SidebarSection.playbooks)
                Label("Tags", systemImage: SidebarSection.tags.icon)
                    .tag(SidebarSection.tags)
            }

            // Trash section (no header)
            Section {
                Label("Trash", systemImage: SidebarSection.trash.icon)
                    .tag(SidebarSection.trash)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Scrollsmith")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Capture button
                Button {
                    showCapture = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Add video")

                // Settings button
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authViewModel)
                .environmentObject(subscriptionViewModel)
        }
        .fullScreenCover(isPresented: $showCapture) {
            NavigationStack {
                CaptureView()
                    .environmentObject(authViewModel)
                    .environmentObject(uploadQueueService)
                    .environment(\.modelContext, modelContext)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showCapture = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationSplitView {
        SidebarView(selection: .constant(.library))
            .environmentObject(AuthViewModel())
            .environmentObject(SubscriptionViewModel())
            .environmentObject(UploadQueueService.shared)
    } detail: {
        Text("Detail View")
    }
}
