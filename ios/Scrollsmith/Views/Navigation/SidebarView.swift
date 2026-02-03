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

    /// Playbook data for sidebar display
    @State private var playbookViewModel = PlaybookViewModel()

    // MARK: - Environment

    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @EnvironmentObject private var uploadQueueService: UploadQueueService
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        // CRITICAL: List MUST use selection binding
        List(selection: $selection) {
            // Types section - filters by video source
            Section("Types") {
                ForEach(VideoType.allCases) { type in
                    Button {
                        // Set type filter and navigate to library
                        navigationModel.selectedType = type
                        selection = .library
                    } label: {
                        Label(type.rawValue, systemImage: type.icon)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Library section
            Section("Library") {
                Button {
                    // Clear all filters to show all videos
                    navigationModel.selectedType = nil as VideoType?
                    navigationModel.selectedPlaybookId = nil as UUID?
                    navigationModel.selectedPlaybookName = nil as String?
                    navigationModel.selectedTag = nil as String?
                    selection = .library
                } label: {
                    Label("All Videos", systemImage: SidebarSection.library.icon)
                }
                .buttonStyle(.plain)
            }

            // Playbooks section - shows user's playbooks with filtering
            Section("Playbooks") {
                ForEach(playbookViewModel.playbooks) { playbook in
                    Button {
                        // Set playbook filter and navigate to library
                        navigationModel.selectedPlaybookId = playbook.id
                        navigationModel.selectedPlaybookName = playbook.name
                        navigationModel.selectedType = nil as VideoType?  // Clear type filter
                        selection = .library
                    } label: {
                        Label {
                            HStack {
                                Text(playbook.name)
                                Spacer()
                                Text("\(playbook.videoCount)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        } icon: {
                            Image(systemName: playbook.isSystem ? "star.fill" : "folder")
                                .foregroundStyle(playbook.isSystem ? .yellow : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Organization section (Tags only for now)
            Section("Organization") {
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
        .task {
            // Load playbooks when sidebar appears
            await playbookViewModel.loadPlaybooks()
        }
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
