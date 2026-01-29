import SwiftUI

/// A celebration overlay that shows confetti particles bursting from a point.
///
/// Use this for delightful moments like habit completion, streaks, or achievements.
struct CelebrationView: View {
    let isActive: Bool
    let particleCount: Int
    let colors: [Color]

    @State private var particles: [ConfettiParticle] = []

    init(
        isActive: Bool,
        particleCount: Int = 20,
        colors: [Color] = [Theme.accent, Theme.Semantic.success, .yellow, .orange, .pink]
    ) {
        self.isActive = isActive
        self.particleCount = particleCount
        self.colors = colors
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                triggerCelebration()
            }
        }
        .allowsHitTesting(false)
    }

    private func triggerCelebration() {
        // Generate particles
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? Theme.accent,
                size: CGFloat.random(in: 4...8),
                position: CGPoint(x: 20, y: 20), // Start from completion button area
                velocity: CGPoint(
                    x: CGFloat.random(in: -100...100),
                    y: CGFloat.random(in: -150 ... -50)
                ),
                opacity: 1.0
            )
        }

        // Animate particles outward and fade
        withAnimation(.easeOut(duration: 0.6)) {
            particles = particles.map { particle in
                var updated = particle
                updated.position = CGPoint(
                    x: particle.position.x + particle.velocity.x,
                    y: particle.position.y + particle.velocity.y + 100 // gravity
                )
                updated.opacity = 0
                return updated
            }
        }

        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            particles = []
        }
    }
}

/// A single confetti particle.
struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    let velocity: CGPoint
    var opacity: Double
}

/// A checkmark that bounces when it appears.
struct AnimatedCheckmark: View {
    let isCompleted: Bool
    let color: Color

    @State private var scale: CGFloat = 1.0
    @State private var showCheckmark = false

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(isCompleted ? color : Theme.Text.tertiary, lineWidth: 2)
                .frame(width: 28, height: 28)

            // Filled background when completed
            if isCompleted {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .scaleEffect(showCheckmark ? 1.0 : 0.0)
            }

            // Checkmark
            if isCompleted && showCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(scale)
            }
        }
        .onChange(of: isCompleted) { _, newValue in
            if newValue {
                animateCompletion()
            } else {
                showCheckmark = false
                scale = 1.0
            }
        }
        .onAppear {
            // Set initial state without animation
            if isCompleted {
                showCheckmark = true
            }
        }
    }

    private func animateCompletion() {
        // Trigger haptic
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Show and bounce
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            showCheckmark = true
            scale = 1.3
        }

        // Return to normal size
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7).delay(0.15)) {
            scale = 1.0
        }
    }
}

/// A compact completion button with built-in animation.
struct CompletionButton: View {
    let isCompleted: Bool
    let onComplete: () -> Void

    @State private var showCelebration = false
    @State private var justCompleted = false

    var body: some View {
        ZStack {
            Button(action: {
                if !isCompleted {
                    justCompleted = true
                    showCelebration = true
                    onComplete()

                    // Reset celebration state after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showCelebration = false
                    }
                }
            }) {
                AnimatedCheckmark(
                    isCompleted: isCompleted || justCompleted,
                    color: Theme.Semantic.success
                )
            }
            .buttonStyle(.plain)
            .disabled(isCompleted)

            // Celebration overlay
            CelebrationView(isActive: showCelebration, particleCount: 12)
                .frame(width: 100, height: 100)
                .offset(x: -20, y: -20)
        }
    }
}

// MARK: - Preview

#Preview("Completion Button") {
    VStack(spacing: 40) {
        CompletionButton(isCompleted: false, onComplete: {})
        CompletionButton(isCompleted: true, onComplete: {})
    }
    .padding(50)
}

#Preview("Animated Checkmark") {
    VStack(spacing: 20) {
        AnimatedCheckmark(isCompleted: false, color: Theme.Semantic.success)
        AnimatedCheckmark(isCompleted: true, color: Theme.Semantic.success)
    }
    .padding()
}
