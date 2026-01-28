import SwiftUI

/// Large screen title using Satoshi font.
///
/// Use this instead of `.navigationTitle()` for custom branded headers.
struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.largeTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
    }
}

/// Section title using Satoshi font.
struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ScreenTitle(text: "Playbooks")
        SectionTitle(text: "My Playbooks")

        Text("Content goes here")
            .padding(.horizontal)
    }
    .background(Theme.Background.primary)
}
