import SwiftUI

/// A styled tag/chip component.
struct TagView: View {
    let text: String
    var icon: String? = nil
    var style: TagStyle = .default

    enum TagStyle {
        case `default`  // Violet
        case secondary  // Gray
        case pro        // Gradient
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(Typography.caption)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(background)
        .foregroundColor(foregroundColor)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .default:
            Theme.accent.opacity(0.1)
        case .secondary:
            Theme.Text.secondary.opacity(0.1)
        case .pro:
            Theme.proGradient
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .default:
            Theme.accent
        case .secondary:
            Theme.Text.secondary
        case .pro:
            .white
        }
    }
}

// MARK: - Preview

#Preview("Tags") {
    HStack(spacing: 8) {
        TagView(text: "Cooking")
        TagView(text: "Fitness", icon: "figure.run")
        TagView(text: "Secondary", style: .secondary)
        TagView(text: "PRO", icon: "sparkles", style: .pro)
    }
    .padding()
}
