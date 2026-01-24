import SwiftUI

/// Displays bullet point summary with clean typography and clear hierarchy.
///
/// ADHD-friendly design: Clean fonts, adequate spacing, high contrast.
/// Per CONTEXT.md: Claude decides numbered vs bulleted based on content type.
struct BulletSummaryView: View {
    let bullets: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { index, bullet in
                    BulletRow(text: bullet, index: index)
                }
            }
            .padding()
        }
    }
}

// MARK: - Bullet Row

private struct BulletRow: View {
    let text: String
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Bullet indicator
            Circle()
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            // Content
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)  // ADHD-friendly: adequate spacing
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

extension BulletSummaryView {
    static var empty: some View {
        ContentUnavailableView {
            Label("No Summary", systemImage: "doc.text")
        } description: {
            Text("This video doesn't have a bullet summary yet.")
        }
    }
}

#Preview {
    BulletSummaryView(bullets: [
        "First key insight from the video explaining something important",
        "Second point with actionable advice",
        "Third insight about productivity",
        "Fourth bullet with a longer explanation that might wrap to multiple lines on smaller screens",
        "Fifth and final point"
    ])
}
