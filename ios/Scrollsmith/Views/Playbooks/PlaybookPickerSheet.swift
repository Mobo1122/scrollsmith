import SwiftUI

/// Bottom sheet for quickly assigning a Video to a Playbook.
///
/// Features:
/// - Horizontal scrolling chips for quick selection
/// - Favorites shown first
/// - "Remember last selected" highlighting
/// - "See all" button for full list
struct PlaybookPickerSheet: View {
    @Bindable var viewModel: PlaybookViewModel
    let videoId: UUID
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showAllPlaybooks = false
    @State private var isAssigning = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            header

            // Horizontal scrolling chips
            chipScroller

            // See all button
            Button {
                showAllPlaybooks = true
            } label: {
                Text("See all playbooks")
                    .font(.subheadline)
            }
            .padding(.bottom, 8)
        }
        .presentationDetents([.height(180), .medium])
        .presentationDragIndicator(.visible)
        .task {
            if viewModel.playbooks.isEmpty {
                await viewModel.loadPlaybooks()
            }
        }
        .sheet(isPresented: $showAllPlaybooks) {
            allPlaybooksSheet
        }
        .disabled(isAssigning)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("Add to Playbook")
                .font(.headline)
            Spacer()
            Button {
                onDismiss()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var chipScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Favorites first
                if let favorites = viewModel.favoritesPlaybook {
                    PlaybookChip(
                        playbook: favorites,
                        isSelected: viewModel.lastSelectedPlaybookId == favorites.id
                    ) {
                        assignToPlaybook(favorites.id)
                    }
                }

                // User Playbooks
                ForEach(viewModel.userPlaybooks) { playbook in
                    PlaybookChip(
                        playbook: playbook,
                        isSelected: viewModel.lastSelectedPlaybookId == playbook.id
                    ) {
                        assignToPlaybook(playbook.id)
                    }
                }

                // Create new Playbook chip
                CreatePlaybookChip()
            }
            .padding(.horizontal)
        }
    }

    private var allPlaybooksSheet: some View {
        NavigationStack {
            List(viewModel.playbooks) { playbook in
                Button {
                    Task {
                        if await viewModel.assignVideo(videoId, to: playbook.id) {
                            showAllPlaybooks = false
                            onDismiss()
                            dismiss()
                        }
                    }
                } label: {
                    PlaybookRow(playbook: playbook)
                }
            }
            .navigationTitle("All Playbooks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAllPlaybooks = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func assignToPlaybook(_ playbookId: UUID) {
        isAssigning = true
        Task {
            if await viewModel.assignVideo(videoId, to: playbookId) {
                onDismiss()
                dismiss()
            }
            isAssigning = false
        }
    }
}

// MARK: - PlaybookChip

/// A horizontal chip for quick Playbook selection.
struct PlaybookChip: View {
    let playbook: PlaybookDTO
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: playbook.icon ?? "folder")
                    .font(.subheadline)
                Text(playbook.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CreatePlaybookChip

/// A chip for creating a new Playbook inline.
struct CreatePlaybookChip: View {
    @State private var showCreateSheet = false
    @State private var viewModel = PlaybookViewModel()

    var body: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.subheadline)
                Text("New")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCreateSheet) {
            CreatePlaybookSheet(viewModel: viewModel, isPresented: $showCreateSheet)
        }
    }
}

// MARK: - Preview

#Preview {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            PlaybookPickerSheet(
                viewModel: PlaybookViewModel(),
                videoId: UUID(),
                onDismiss: {}
            )
        }
}
