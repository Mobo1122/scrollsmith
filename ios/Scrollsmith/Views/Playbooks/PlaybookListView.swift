import SwiftUI

/// Main view for displaying and managing user's Playbooks.
///
/// Features:
/// - List of all Playbooks with Favorites at top
/// - Swipe actions for edit/delete
/// - Create new Playbook via sheet
/// - Pull to refresh
struct PlaybookListView: View {
    @State private var viewModel = PlaybookViewModel()
    @State private var showCreateSheet = false
    @State private var editingPlaybook: PlaybookDTO?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.playbooks.isEmpty {
                    ProgressView("Loading...")
                } else if let error = viewModel.error, viewModel.playbooks.isEmpty {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
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
            .navigationTitle("Playbooks")
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
    }

    // MARK: - Subviews

    private var playbookList: some View {
        List {
            // Favorites at top (system Playbook)
            if let favorites = viewModel.favoritesPlaybook {
                NavigationLink(destination: PlaybookDetailView(playbook: favorites)) {
                    PlaybookRow(playbook: favorites)
                }
            }

            // User Playbooks
            if !viewModel.userPlaybooks.isEmpty {
                Section("My Playbooks") {
                    ForEach(viewModel.userPlaybooks) { playbook in
                        NavigationLink(destination: PlaybookDetailView(playbook: playbook)) {
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
                            .tint(.blue)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - PlaybookRow

/// A row displaying Playbook info (icon, name, video count).
struct PlaybookRow: View {
    let playbook: PlaybookDTO

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: playbook.icon ?? "folder")
                .foregroundStyle(playbook.isSystem ? .yellow : .blue)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(playbook.name)
                    .font(.headline)
                Text("\(playbook.videoCount) \(playbook.videoCount == 1 ? "video" : "videos")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - CreatePlaybookSheet

/// Sheet for creating a new Playbook.
struct CreatePlaybookSheet: View {
    @Bindable var viewModel: PlaybookViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playbook Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("New Playbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createPlaybook()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isCreating)
    }

    private func createPlaybook() {
        isCreating = true
        Task {
            if await viewModel.createPlaybook(name: name.trimmingCharacters(in: .whitespaces)) {
                isPresented = false
            }
            isCreating = false
        }
    }
}

// MARK: - EditPlaybookSheet

/// Sheet for editing an existing Playbook's name.
struct EditPlaybookSheet: View {
    @Bindable var viewModel: PlaybookViewModel
    let playbook: PlaybookDTO
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playbook Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Edit Playbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlaybook()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            name = playbook.name
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isSaving)
    }

    private func savePlaybook() {
        isSaving = true
        Task {
            if await viewModel.updatePlaybook(id: playbook.id, name: name.trimmingCharacters(in: .whitespaces)) {
                isPresented = false
            }
            isSaving = false
        }
    }
}

// MARK: - Preview

#Preview {
    PlaybookListView()
}
