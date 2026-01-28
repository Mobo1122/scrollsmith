import SwiftUI

/// A styled card container with consistent appearance.
struct StyledCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.cardPadding)
            .background(Theme.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .shadow(
                color: colorScheme == .light ? Theme.cardShadow.color : .clear,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
    }
}

/// Card modifier for applying card styling to any view.
struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .background(Theme.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .shadow(
                color: colorScheme == .light ? Theme.cardShadow.color : .clear,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
    }
}

extension View {
    /// Apply card styling to any view.
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Preview

#Preview("Card Styles") {
    VStack(spacing: 24) {
        StyledCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Title")
                    .font(Typography.title3)
                Text("Card content goes here with some descriptive text.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.Text.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        HStack {
            Text("Using modifier")
            Spacer()
            Image(systemName: "chevron.right")
        }
        .cardStyle()
    }
    .padding()
    .background(Theme.Background.primary)
}
