import SwiftUI

/// Search view for videos with debounced real-time results.
///
/// Displays a searchable list that queries the backend full-text search.
/// Search is debounced (250ms) to avoid excessive API calls while typing.
struct VideoSearchView: View {
    // MARK: - State

    @State private var viewModel = SearchViewModel()

    /// Optional playbook ID to scope search to a specific playbook.
    var playbookId: UUID?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.debouncedQuery.isEmpty {
                    ContentUnavailableView(
                        "Search Videos",
                        systemImage: "magnifyingglass",
                        description: Text("Search across transcripts, summaries, and tags")
                    )
                } else if viewModel.isSearching {
                    ProgressView("Searching...")
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No videos match \"\(viewModel.debouncedQuery)\"")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.results) { result in
                                SearchResultCard(result: result)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.searchText, prompt: "Search videos...")
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.onSearchTextChanged(newValue)
            }
            .onChange(of: viewModel.debouncedQuery) { _, _ in
                Task { await viewModel.performSearch() }
            }
            .onAppear {
                viewModel.playbookId = playbookId
            }
        }
    }
}

// MARK: - Search Result Card

/// A card displaying a single search result.
struct SearchResultCard: View {
    let result: VideoSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }

            // Tags
            if let tags = result.tags, !tags.isEmpty {
                Text(tags.prefix(2).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Highlight (if available)
            if let highlight = result.highlight, !highlight.isEmpty {
                // Strip <mark> tags for simple display (Phase 7 can add proper highlighting)
                let cleanHighlight = highlight
                    .replacingOccurrences(of: "<mark>", with: "")
                    .replacingOccurrences(of: "</mark>", with: "")
                Text(cleanHighlight)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
