import SwiftUI

/// View for editing video tags with a chip-style interface.
///
/// Allows adding and removing tags with:
/// - Text field for adding new tags
/// - Chip-style display of current tags
/// - Flow layout for natural tag wrapping
/// - Maximum 20 tags limit
struct VideoTagEditorView: View {
    // MARK: - Properties

    let video: VideoDTO
    var onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tags: [String] = []
    @State private var newTagText: String = ""
    @State private var isSaving: Bool = false
    @State private var error: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Tag input field
                HStack {
                    TextField("Add tag...", text: $newTagText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addTag()
                        }

                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)

                // Tag chips
                if tags.isEmpty {
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag.slash",
                        description: Text("Add tags to organize this video")
                    )
                    .frame(maxHeight: 200)
                } else {
                    ScrollView {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                TagChip(tag: tag) {
                                    removeTag(tag)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // Error display
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveTags() }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                tags = video.tags ?? []
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Tag Management

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !tags.contains(trimmed) else {
            newTagText = ""
            return  // Ignore duplicate
        }
        guard tags.count < 20 else {
            error = "Maximum 20 tags allowed"
            return
        }

        tags.append(trimmed)
        newTagText = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func saveTags() async {
        isSaving = true
        error = nil

        do {
            let response = try await APIClient.shared.updateVideoTags(videoId: video.id, tags: tags)
            onSave(response.tags)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Tag Chip

/// A single tag displayed as a removable chip.
struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.subheadline)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.15))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout

/// A layout that arranges views in a flow, wrapping to new lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}
