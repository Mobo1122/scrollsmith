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

    /// Tag data for sidebar display
    @State private var tagViewModel = TagViewModel()

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

            // Tags section - shows all tags with video counts
            Section("Tags") {
                if tagViewModel.isLoading {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading tags...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if tagViewModel.tags.isEmpty {
                    Text("No tags yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tagViewModel.tags) { tag in
                        Button {
                            // Set tag filter and navigate to library
                            navigationModel.selectedTag = tag.name
                            navigationModel.selectedType = nil as VideoType?  // Clear type filter
                            navigationModel.selectedPlaybookId = nil as UUID?  // Clear playbook filter
                            selection = .library
                        } label: {
                            Label {
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    Text("\(tag.videoCount)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            } icon: {
                                Image(systemName: "tag")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Recently Deleted section (no header)
            Section {
                Label("Recently Deleted", systemImage: SidebarSection.trash.icon)
                    .tag(SidebarSection.trash)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Scrollsmith")
        .task {
            // Load playbooks and tags when sidebar appears
            async let playbooks: Void = playbookViewModel.loadPlaybooks()
            async let tags: Void = tagViewModel.loadTags()
            _ = await (playbooks, tags)
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
