import SwiftUI

/// Scrollsmith design system entry point.
///
/// Provides centralized access to colors, typography, and spacing.
enum Theme {

    // MARK: - Colors

    /// Primary brand accent (Violet)
    static let accent = Color.accentColor

    /// Background colors
    enum Background {
        static let primary = Color("BackgroundPrimary")
        static let secondary = Color("BackgroundSecondary")
        static let tertiary = Color("BackgroundTertiary")
    }

    /// Text colors (use semantic system colors)
    enum Text {
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let tertiary = Color(uiColor: .tertiaryLabel)
    }

    /// Semantic colors
    enum Semantic {
        static let success = Color("Success")
        static let warning = Color("Warning")
        static let error = Color("Error")
    }

    // MARK: - Shadows

    /// Subtle card shadow for light mode
    static let cardShadow = Shadow(
        color: Color.black.opacity(0.08),
        radius: 3,
        x: 0,
        y: 1
    )

    // MARK: - Gradients

    /// Pro badge gradient
    static let proGradient = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Shadow configuration for consistent elevation.
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}
