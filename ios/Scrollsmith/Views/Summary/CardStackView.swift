import SwiftUI

/// Card stack container with progress indicator and visual stacking.
///
/// CONTEXT.md decisions:
/// - Centered card with 1-2 smaller, dimmed cards behind
/// - Toast confirmation after swipe
/// - Buttons at bottom for tap/keyboard users
struct CardStackView: View {
    let cards: [CardItem]
    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var toastMessage: String?
    @State private var showToast = false

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            progressView

            // Card stack
            ZStack {
                // Background cards (stacked hint)
                ForEach(backgroundCardIndices, id: \.self) { index in
                    cardBackground(at: index)
                }

                // Current card
                if currentIndex < cards.count {
                    SwipeableCardView(
                        card: cards[currentIndex],
                        offset: $offset,
                        onSwipeRight: { handleSwipe(action: .complete) },
                        onSwipeLeft: { handleSwipe(action: .skip) }
                    )
                }
            }
            .frame(height: 320)

            // Action buttons (accessibility fallback)
            actionButtons

            Spacer()
        }
        .padding()
        .overlay(alignment: .bottom) {
            toastView
        }
        .overlay {
            completionOverlay
        }
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 8) {
            Text("\(min(currentIndex + 1, cards.count)) of \(cards.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(currentIndex), total: Double(cards.count))
                .tint(.accentColor)
        }
    }

    // MARK: - Background Cards (Stack Hint)

    private var backgroundCardIndices: [Int] {
        // Show up to 2 cards behind the current one
        let indices = [currentIndex + 1, currentIndex + 2]
        return indices.filter { $0 < cards.count }
    }

    private func cardBackground(at index: Int) -> some View {
        let offset = CGFloat(index - currentIndex)

        return RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray6))
            .frame(height: 280)
            .scaleEffect(1 - (offset * 0.05))
            .offset(y: offset * 8)
            .opacity(1 - (offset * 0.3))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 40) {
            // Skip button
            Button {
                withAnimation(.easeOut(duration: 0.3)) {
                    offset.width = -400
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handleSwipe(action: .skip)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                    )
            }
            .disabled(currentIndex >= cards.count)

            // Complete button
            Button {
                withAnimation(.easeOut(duration: 0.3)) {
                    offset.width = 400
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handleSwipe(action: .complete)
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    )
            }
            .disabled(currentIndex >= cards.count)
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        Group {
            if showToast, let message = toastMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Swipe Handling

    private enum SwipeAction {
        case complete, skip
    }

    private func handleSwipe(action: SwipeAction) {
        // Reset offset
        offset = .zero

        // Show toast
        switch action {
        case .complete:
            toastMessage = "Card completed"
        case .skip:
            toastMessage = "Card skipped"
        }

        withAnimation {
            showToast = true
        }

        // Hide toast after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showToast = false
            }
        }

        // Advance to next card
        withAnimation(.spring()) {
            currentIndex += 1
        }
    }

    // MARK: - Completion View

    @ViewBuilder
    private var completionOverlay: some View {
        if currentIndex >= cards.count {
            ContentUnavailableView {
                Label("All Done!", systemImage: "checkmark.circle.fill")
            } description: {
                Text("You've reviewed all \(cards.count) cards.")
            }
        }
    }
}

// MARK: - Empty State

extension CardStackView {
    static var empty: some View {
        ContentUnavailableView {
            Label("No Cards", systemImage: "rectangle.stack")
        } description: {
            Text("This video doesn't have card summaries.")
        }
    }
}

#Preview {
    CardStackView(cards: [
        CardItem(title: "Start Small", content: "Begin with just 5 minutes of meditation.", category: .tip),
        CardItem(title: "Warning", content: "Don't skip days - consistency is key.", category: .warning),
        CardItem(title: "Insight", content: "Morning meditation has higher completion rates.", category: .insight),
        CardItem(title: "Take Action", content: "Set a daily alarm for your meditation time.", category: .action)
    ])
}
