import SwiftUI

/// Scrollsmith spacing system based on 8pt grid.
enum Spacing {
    /// 4pt - Minimal spacing
    static let xxs: CGFloat = 4

    /// 8pt - Tight spacing
    static let xs: CGFloat = 8

    /// 12pt - Compact spacing
    static let sm: CGFloat = 12

    /// 16pt - Standard spacing (default)
    static let md: CGFloat = 16

    /// 24pt - Comfortable spacing
    static let lg: CGFloat = 24

    /// 32pt - Generous spacing
    static let xl: CGFloat = 32

    /// 48pt - Section spacing
    static let xxl: CGFloat = 48

    // MARK: - Component Specific

    /// Card internal padding
    static let cardPadding: CGFloat = 16

    /// Card corner radius
    static let cardRadius: CGFloat = 16

    /// Button corner radius
    static let buttonRadius: CGFloat = 12

    /// Input field height
    static let inputHeight: CGFloat = 48

    /// Minimum tap target
    static let minTapTarget: CGFloat = 44

    /// Button height
    static let buttonHeight: CGFloat = 50
}
