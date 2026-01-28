import SwiftUI

/// Primary button style - solid violet fill.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

/// Secondary button style - violet text with subtle background.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundColor(Theme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(Theme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

/// Ghost button style - violet text only.
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundColor(Theme.accent)
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.5)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Destructive button style - red text with subtle background.
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundColor(Theme.Semantic.error)
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(Theme.Semantic.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply primary button styling.
    func primaryButtonStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }

    /// Apply secondary button styling.
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }

    /// Apply ghost button styling.
    func ghostButtonStyle() -> some View {
        self.buttonStyle(GhostButtonStyle())
    }

    /// Apply destructive button styling.
    func destructiveButtonStyle() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
    }
}

// MARK: - Preview

#Preview("Button Styles") {
    VStack(spacing: 16) {
        Button("Primary Button") {}
            .primaryButtonStyle()

        Button("Secondary Button") {}
            .secondaryButtonStyle()

        Button("Ghost Button") {}
            .ghostButtonStyle()

        Button("Destructive Button") {}
            .destructiveButtonStyle()

        Button("Disabled Primary") {}
            .primaryButtonStyle()
            .disabled(true)
    }
    .padding()
}
