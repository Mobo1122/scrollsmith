import SwiftUI

/// Individual swipeable card with drag gesture and category-based styling.
///
/// CONTEXT.md decisions:
/// - Swipe right = done/complete, left = skip
/// - Labels near edges during drag ("Complete", "Skip")
/// - Rotation follows drag offset
/// - Snap back if not past threshold
struct SwipeableCardView: View {
    let card: CardItem
    @Binding var offset: CGSize
    let onSwipeRight: () -> Void  // Complete/Done
    let onSwipeLeft: () -> Void   // Skip

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            // Card background with category styling
            cardBackground

            // Content
            VStack(alignment: .leading, spacing: 16) {
                categoryBadge
                titleText
                contentText
            }
            .padding(24)

            // Swipe labels overlay
            swipeLabels
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .offset(x: offset.width)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .gesture(dragGesture)
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(card.category.backgroundColor)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Category Badge

    private var categoryBadge: some View {
        HStack {
            Image(systemName: card.category.iconName)
                .font(.caption)
            Text(card.category.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(card.category.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(card.category.accentColor.opacity(0.15))
        )
    }

    // MARK: - Title

    private var titleText: some View {
        Text(card.title)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
    }

    // MARK: - Content

    private var contentText: some View {
        Text(card.content)
            .font(.body)
            .foregroundStyle(.secondary)
            .lineSpacing(4)
    }

    // MARK: - Swipe Labels

    private var swipeLabels: some View {
        HStack {
            // Skip label (left)
            Text("Skip")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 3)
                )
                .opacity(offset.width < -20 ? Double(-offset.width / 100) : 0)

            Spacer()

            // Complete label (right)
            Text("Done")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 3)
                )
                .opacity(offset.width > 20 ? Double(offset.width / 100) : 0)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
            .onEnded { value in
                if offset.width > swipeThreshold {
                    // Swipe right - complete
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset.width = 400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSwipeRight()
                    }
                } else if offset.width < -swipeThreshold {
                    // Swipe left - skip
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset.width = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSwipeLeft()
                    }
                } else {
                    // Snap back
                    withAnimation(.interactiveSpring()) {
                        offset = .zero
                    }
                }
            }
    }
}

// MARK: - CardCategory Extensions

extension CardCategory {
    var displayName: String {
        switch self {
        case .tip: return "Tip"
        case .warning: return "Warning"
        case .insight: return "Insight"
        case .action: return "Action"
        }
    }

    var iconName: String {
        switch self {
        case .tip: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .insight: return "eye.fill"
        case .action: return "bolt.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .tip: return .yellow
        case .warning: return .orange
        case .insight: return Theme.accent
        case .action: return .green
        }
    }

    var backgroundColor: Color {
        switch self {
        case .tip: return Color(.systemBackground)
        case .warning: return Color(.systemBackground)
        case .insight: return Color(.systemBackground)
        case .action: return Color(.systemBackground)
        }
    }
}

#Preview {
    SwipeableCardView(
        card: CardItem(
            title: "Start Small",
            content: "Begin with just 5 minutes of meditation. Consistency matters more than duration when building a new habit.",
            category: .tip
        ),
        offset: .constant(.zero),
        onSwipeRight: {},
        onSwipeLeft: {}
    )
    .padding()
}
