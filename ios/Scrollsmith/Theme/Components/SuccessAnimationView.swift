import SwiftUI

/// An animated success view with a bouncing checkmark and optional confetti.
///
/// Use this for completion states like processing complete, habits created, etc.
struct SuccessAnimationView: View {
    let title: String
    let subtitle: String?
    let showConfetti: Bool

    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0
    @State private var showParticles = false

    init(title: String, subtitle: String? = nil, showConfetti: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self.showConfetti = showConfetti
    }

    var body: some View {
        ZStack {
            // Confetti particles
            if showConfetti {
                SuccessConfettiView(isActive: showParticles)
            }

            VStack(spacing: 20) {
                // Animated checkmark
                ZStack {
                    // Outer ring pulse
                    Circle()
                        .stroke(Theme.Semantic.success.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .scaleEffect(ringScale)

                    // Inner circle
                    Circle()
                        .fill(Theme.Semantic.success)
                        .frame(width: 70, height: 70)
                        .scaleEffect(checkmarkScale)

                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }

                // Title
                Text(title)
                    .font(Typography.title3)
                    .fontWeight(.semibold)
                    .opacity(textOpacity)

                // Subtitle
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.subheadline)
                        .foregroundStyle(Theme.Text.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)
                }
            }
        }
        .onAppear {
            animateSuccess()
        }
    }

    private func animateSuccess() {
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        // Ring pulse
        withAnimation(.easeOut(duration: 0.4)) {
            ringScale = 1.2
        }
        withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
            ringScale = 1.0
        }

        // Checkmark bounce in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) {
            checkmarkScale = 1.0
            checkmarkOpacity = 1.0
        }

        // Text fade in
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            textOpacity = 1.0
        }

        // Trigger confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showParticles = true
        }
    }
}

/// Confetti particles that burst from center for success moments.
struct SuccessConfettiView: View {
    let isActive: Bool

    @State private var particles: [SuccessParticle] = []

    private let colors: [Color] = [
        Theme.accent,
        Theme.Semantic.success,
        .yellow,
        .orange,
        .pink,
        .cyan
    ]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2 - 40)

            ZStack {
                ForEach(particles) { particle in
                    particle.shape
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .rotationEffect(particle.rotation)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    triggerConfetti(from: center)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func triggerConfetti(from center: CGPoint) {
        // Generate particles in a burst pattern
        particles = (0..<30).map { i in
            let angle = Double(i) * (360.0 / 30.0) * .pi / 180.0
            let speed = CGFloat.random(in: 80...150)

            return SuccessParticle(
                color: colors.randomElement() ?? Theme.accent,
                size: CGFloat.random(in: 6...12),
                shape: [AnyShape(Circle()), AnyShape(Rectangle()), AnyShape(Capsule())].randomElement()!,
                position: center,
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed - 50 // bias upward
                ),
                rotation: .degrees(Double.random(in: 0...360)),
                opacity: 1.0
            )
        }

        // Animate outward with gravity
        withAnimation(.easeOut(duration: 0.8)) {
            particles = particles.map { particle in
                var updated = particle
                updated.position = CGPoint(
                    x: particle.position.x + particle.velocity.x,
                    y: particle.position.y + particle.velocity.y + 80 // gravity
                )
                updated.rotation = particle.rotation + .degrees(Double.random(in: 90...180))
                updated.opacity = 0
                return updated
            }
        }

        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            particles = []
        }
    }
}

/// A single confetti particle for success animation.
struct SuccessParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let shape: AnyShape
    var position: CGPoint
    let velocity: CGPoint
    var rotation: Angle
    var opacity: Double
}

// MARK: - Preview

#Preview("Success Animation") {
    SuccessAnimationView(
        title: "3 Habits Created!",
        subtitle: "You'll find your new habits in the Habits tab."
    )
    .padding()
}

#Preview("Success - No Subtitle") {
    SuccessAnimationView(
        title: "Processing Complete!",
        showConfetti: true
    )
    .padding()
}
