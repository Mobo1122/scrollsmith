import SwiftUI

/// Grid view for displaying videos with multi-select, bulk actions, and context menu.
///
/// Supports:
/// - Long-press to enter selection mode
/// - Bulk delete, move, and favorite actions
/// - Context menu with "Edit Tags" option
/// - Delete confirmation dialog
struct VideoGridView: View {
    // MARK: - Properties

    let playbookId: UUID?
    let showUncategorized: Bool

    @State private var videos: [VideoDTO] = []
    @State private var selection = VideoSelectionManager()
    @State private var playbooks = PlaybookViewModel()
    @State private var isLoading = false
    @State private var error: String?

    @State private var showDeleteConfirm = false
    @State private var showMoveSheet = false
    @State private var editingTagsForVideo: VideoDTO?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading && videos.isEmpty {
                ProgressView("Loading...")
            } else if videos.isEmpty {
                ContentUnavailableView(
                    "No Videos",
                    systemImage: "video.slash",
                    description: Text(showUncategorized ? "All videos are organized" : "Add videos to get started")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(videos) { video in
                            NavigationLink {
                                SummaryDisplayView(video: video, isPro: false)
                            } label: {
                                VideoGridItem(
                                    video: video,
                                    isSelected: selection.isSelected(video.id),
                                    isSelecting: selection.isSelecting
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(selection.isSelecting)
                            .onTapGesture {
                                if selection.isSelecting {
                                    selection.toggle(video.id)
                                }
                            }
                            .onLongPressGesture {
                                selection.enterSelectionMode(with: video.id)
                            }
                            .contextMenu {
                                Button {
                                    editingTagsForVideo = video
                                } label: {
                                    Label("Edit Tags", systemImage: "tag")
                                }
                                Button(role: .destructive) {
                                    selection.enterSelectionMode(with: video.id)
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if selection.isSelecting {
                    Button("Done") {
                        selection.clearSelection()
                    }
                } else {
                    Button("Select") {
                        selection.isSelecting = true
                    }
                    .disabled(videos.isEmpty)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selection.hasSelection {
                BulkActionBar(
                    selectedCount: selection.selectedCount,
                    onDelete: { showDeleteConfirm = true },
                    onMove: { showMoveSheet = true },
                    onFavorite: {
                        Task {
                            await bulkAddToFavorites()
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            "Delete \(selection.selectedCount) video\(selection.selectedCount == 1 ? "" : "s")?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await bulkDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showMoveSheet) {
            BulkMoveSheet(
                selectedCount: selection.selectedCount,
                viewModel: playbooks
            ) { playbook in
                Task { await bulkMove(to: playbook.id) }
            }
        }
        .sheet(item: $editingTagsForVideo) { video in
            VideoTagEditorView(video: video) { updatedTags in
                // Update local video with new tags
                if let index = videos.firstIndex(where: { $0.id == video.id }) {
                    videos[index] = VideoDTO(
                        id: video.id,
                        sourceUrl: video.sourceUrl,
                        summaryBullets: video.summaryBullets,
                        tags: updatedTags,
                        createdAt: video.createdAt
                    )
                }
            }
        }
        .task {
            await loadVideos()
            await playbooks.loadPlaybooks()
        }
        .refreshable {
            await loadVideos()
        }
    }

    // MARK: - Data Loading

    private func loadVideos() async {
        isLoading = true
        do {
            videos = try await APIClient.shared.getVideos(
                playbookId: playbookId,
                uncategorized: showUncategorized
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Bulk Actions

    private func bulkDelete() async {
        do {
            _ = try await APIClient.shared.bulkDeleteVideos(ids: Array(selection.selectedIds))
            videos.removeAll { selection.isSelected($0.id) }
            selection.clearSelection()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func bulkMove(to playbookId: UUID) async {
        do {
            _ = try await APIClient.shared.bulkMoveVideos(ids: Array(selection.selectedIds), to: playbookId)
            selection.clearSelection()
            showMoveSheet = false
            await loadVideos()  // Refresh to reflect changes
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func bulkAddToFavorites() async {
        do {
            _ = try await APIClient.shared.bulkAddToFavorites(ids: Array(selection.selectedIds))
            selection.clearSelection()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Supporting Views

/// A single video item in the grid.
struct VideoGridItem: View {
    let video: VideoDTO
    let isSelected: Bool
    let isSelecting: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }

                if let tags = video.tags, !tags.isEmpty {
                    Text(tags.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .opacity(isSelected ? 0.7 : 1.0)

            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .white)
                    .padding(8)
            }
        }
    }
}

/// Bottom bar showing bulk action buttons.
struct BulkActionBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onMove: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        HStack {
            Text("\(selectedCount) selected")
                .font(.subheadline)

            Spacer()

            Button {
                onFavorite()
            } label: {
                Image(systemName: "star")
            }

            Button {
                onMove()
            } label: {
                Image(systemName: "folder")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

/// Sheet for selecting a playbook to move videos to.
struct BulkMoveSheet: View {
    let selectedCount: Int
    @Bindable var viewModel: PlaybookViewModel
    let onSelect: (PlaybookDTO) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.playbooks) { playbook in
                Button {
                    onSelect(playbook)
                    dismiss()
                } label: {
                    PlaybookRow(playbook: playbook)
                }
            }
            .navigationTitle("Move \(selectedCount) video\(selectedCount == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// A row displaying a playbook with icon and video count.
struct PlaybookRow: View {
    let playbook: PlaybookDTO

    var body: some View {
        HStack {
            Image(systemName: playbook.icon ?? "folder")
                .foregroundStyle(playbook.isSystem ? .yellow : .blue)
                .font(.title2)

            VStack(alignment: .leading) {
                Text(playbook.name)
                    .font(.headline)
                Text("\(playbook.videoCount) videos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Default Initializer

extension VideoGridView {
    /// Creates a VideoGridView for "All Videos" view.
    init() {
        self.init(playbookId: nil, showUncategorized: false)
    }
}
