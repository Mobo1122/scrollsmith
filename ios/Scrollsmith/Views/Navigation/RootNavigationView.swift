import SwiftUI

/// Root navigation container using NavigationSplitView.
///
/// Automatically adapts between:
/// - iPhone: Collapsed stack with overlay sidebar
/// - iPad: Persistent sidebar in split-view layout
///
/// Following RESEARCH.md Pattern 3 and Pattern 5 for correct implementation.
struct RootNavigationView: View {
    // MARK: - State

    /// Navigation model holding all navigation state.
    /// Using @State ensures persistence across size class changes.
    @State private var navigationModel = NavigationModel()

    // MARK: - Environment

    /// Horizontal size class for potential adjustments.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Environment objects passed through from app root.
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @EnvironmentObject private var uploadQueueService: UploadQueueService

    // MARK: - Computed Properties

    /// Dynamic navigation title based on current filter selection
    private var navigationTitle: String {
        if let type = navigationModel.selectedType {
            return type.rawValue
        }
        if let playbookName = navigationModel.selectedPlaybookName {
            return playbookName
        }
        if let tag = navigationModel.selectedTag {
            return tag  // Tag name is the filter, use directly
        }
        return "Library"
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView(
            columnVisibility: $navigationModel.columnVisibility,
            preferredCompactColumn: .constant(.detail)  // iPhone starts on detail (Library)
        ) {
            SidebarView(selection: $navigationModel.selectedSection)
                .environmentObject(authViewModel)
                .environmentObject(subscriptionViewModel)
                .environmentObject(uploadQueueService)
                .environment(navigationModel)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Detail Content

    /// Detail view content that switches based on sidebar selection.
    /// Uses ZStack to prevent conditional view update issues (Pitfall 6).
    @ViewBuilder
    private var detailContent: some View {
        NavigationStack(path: navigationModel.currentPath) {
            // ZStack prevents conditional view update issues
            ZStack {
                switch navigationModel.selectedSection {
                case .library:
                    VideoFeedView(
                        playbookId: navigationModel.selectedPlaybookId,
                        showUncategorized: false,
                        type: navigationModel.selectedType
                    )
                    .navigationTitle(navigationTitle)
                    .navigationBarTitleDisplayMode(.large)

                case .playbooks:
                    // PlaybookListView has its own NavigationStack internally.
                    // For now, extract just its content without the NavigationStack wrapper.
                    // This creates a nested NavigationStack which works but is not ideal.
                    // TODO: Refactor PlaybookListView in Phase 15 to be navigation-agnostic.
                    PlaybookListContent()
                        .navigationTitle("Playbooks")
                        .navigationBarTitleDisplayMode(.large)

                case .tags:
                    ContentUnavailableView(
                        "Tags",
                        systemImage: SidebarSection.tags.icon,
                        description: Text("Filter by tags - Coming in Phase 15")
                    )
                    .navigationTitle("Tags")
                    .navigationBarTitleDisplayMode(.large)

                case .trash:
                    ContentUnavailableView(
                        "Trash",
                        systemImage: SidebarSection.trash.icon,
                        description: Text("Deleted videos - Coming in Phase 15")
                    )
                    .navigationTitle("Trash")
                    .navigationBarTitleDisplayMode(.large)

                case .none:
                    ContentUnavailableView(
                        "Select a Section",
                        systemImage: "sidebar.left",
                        description: Text("Choose from the sidebar")
                    )
                }
            }
            .navigationDestination(for: VideoDTO.self) { video in
                SummaryDisplayView(video: video)
                    .environmentObject(subscriptionViewModel)
            }
            .navigationDestination(for: PlaybookDTO.self) { playbook in
                PlaybookDetailView(playbook: playbook)
            }
        }
    }
}

// MARK: - PlaybookListContent

/// Extracted content from PlaybookListView without NavigationStack wrapper.
/// This avoids nested NavigationStack issues in NavigationSplitView.
private struct PlaybookListContent: View {
    @State private var viewModel = PlaybookViewModel()
    @State private var showCreateSheet = false
    @State private var editingPlaybook: PlaybookDTO?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.playbooks.isEmpty {
                ProgressView("Loading...")
            } else if let error = viewModel.error, viewModel.playbooks.isEmpty {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if viewModel.playbooks.isEmpty {
                ContentUnavailableView(
                    "No Playbooks",
                    systemImage: "folder",
                    description: Text("Create a Playbook to organize your videos")
                )
            } else {
                playbookList
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.loadPlaybooks()
        }
        .task {
            await viewModel.loadPlaybooks()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePlaybookSheet(viewModel: viewModel, isPresented: $showCreateSheet)
        }
        .sheet(item: $editingPlaybook) { playbook in
            EditPlaybookSheet(
                viewModel: viewModel,
                playbook: playbook,
                isPresented: Binding(
                    get: { editingPlaybook != nil },
                    set: { if !$0 { editingPlaybook = nil } }
                )
            )
        }
    }

    private var playbookList: some View {
        List {
            // Favorites (system Playbook)
            if let favorites = viewModel.favoritesPlaybook {
                NavigationLink(value: favorites) {
                    PlaybookRow(playbook: favorites)
                }
            }

            // Uncategorized videos
            NavigationLink(value: "uncategorized") {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "tray")
                        .foregroundStyle(Theme.Text.secondary)
                        .font(.title2)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uncategorized")
                            .font(Typography.headline)
                        Text("Videos not in any playbook")
                            .font(Typography.footnote)
                            .foregroundStyle(Theme.Text.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }

            // User Playbooks
            if !viewModel.userPlaybooks.isEmpty {
                Section("My Playbooks") {
                    ForEach(viewModel.userPlaybooks) { playbook in
                        NavigationLink(value: playbook) {
                            PlaybookRow(playbook: playbook)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                Task {
                                    await viewModel.deletePlaybook(id: playbook.id)
                                }
                            }

                            Button("Edit") {
                                editingPlaybook = playbook
                            }
                            .tint(Theme.accent)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: String.self) { destination in
            switch destination {
            case "uncategorized":
                VideoFeedView(playbookId: nil, showUncategorized: true, type: nil)
                    .navigationTitle("Uncategorized")
                    .navigationBarTitleDisplayMode(.large)
            default:
                Text("Unknown destination")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootNavigationView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionViewModel())
        .environmentObject(UploadQueueService.shared)
}
