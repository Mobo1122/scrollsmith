import SwiftUI
import SwiftData

/// A view showing upload/processing progress.
///
/// Displays a progress indicator with status text.
/// Used in CaptureView to show processing state.
struct UploadProgressView: View {
    @ObservedObject var queueService = UploadQueueService.shared

    var body: some View {
        if queueService.isProcessing, let item = queueService.currentItem {
            HStack(spacing: 12) {
                ProgressView()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Processing...")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(item.videoPlatform.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Theme.accent.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

/// A badge showing the count of pending uploads.
struct PendingUploadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.red)
                .clipShape(Circle())
        }
    }
}

/// A list view showing pending uploads with retry/delete options.
struct PendingUploadsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<PendingUpload> { $0.status != "completed" },
        sort: \PendingUpload.createdAt,
        order: .reverse
    )
    private var pendingUploads: [PendingUpload]

    @ObservedObject var queueService = UploadQueueService.shared

    var body: some View {
        if pendingUploads.isEmpty {
            ContentUnavailableView(
                "No Pending Videos",
                systemImage: "checkmark.circle",
                description: Text("All videos have been processed")
            )
        } else {
            List {
                ForEach(pendingUploads) { upload in
                    PendingUploadRow(upload: upload)
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await queueService.delete(pendingUploads[index])
                        }
                    }
                }
            }
        }
    }
}

/// A row view for a single pending upload.
struct PendingUploadRow: View {
    let upload: PendingUpload

    var body: some View {
        HStack(spacing: 12) {
            // Platform icon
            Image(systemName: upload.videoPlatform.iconName)
                .font(.title2)
                .foregroundColor(Theme.accent)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(upload.videoPlatform.displayName)
                    .font(.headline)

                Text(upload.sourceURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Status
                HStack {
                    statusBadge
                    Text(upload.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch upload.uploadStatus {
        case .pending:
            Label("Pending", systemImage: "clock")
                .font(.caption2)
                .foregroundColor(.orange)
        case .downloading, .extractingAudio, .loadingModel, .transcribing, .saving:
            Label("Processing", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .foregroundColor(Theme.accent)
        case .completed:
            Label("Done", systemImage: "checkmark.circle")
                .font(.caption2)
                .foregroundColor(.green)
        case .failed:
            Label("Failed", systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }
}

#Preview {
    VStack {
        UploadProgressView()
    }
}

#Preview("Pending List") {
    PendingUploadsListView()
        .modelContainer(for: PendingUpload.self, inMemory: true)
}
