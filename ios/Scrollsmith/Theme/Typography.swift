import SwiftUI

/// Scrollsmith typography system.
///
/// Uses Satoshi for display/headers, SF Pro for body text.
/// Follows iOS Dynamic Type for accessibility.
enum Typography {

    // MARK: - Display (Satoshi)

    /// 34pt Satoshi Bold - Screen titles
    static let largeTitle = Font.custom("Satoshi-Bold", size: 34, relativeTo: .largeTitle)

    /// 28pt Satoshi Medium - Section headers, sheet titles
    static let title = Font.custom("Satoshi-Medium", size: 28, relativeTo: .title)

    /// 20pt Satoshi Medium - Card titles, playbook names
    static let title3 = Font.custom("Satoshi-Medium", size: 20, relativeTo: .title3)

    // MARK: - Body (SF Pro - System)

    /// 17pt SF Pro Semibold - List item titles
    static let headline = Font.headline

    /// 17pt SF Pro Regular - Primary content
    static let body = Font.body

    /// 16pt SF Pro Regular - Secondary content
    static let callout = Font.callout

    /// 15pt SF Pro Regular - Metadata, timestamps
    static let subheadline = Font.subheadline

    /// 13pt SF Pro Regular - Captions, hints
    static let footnote = Font.footnote

    /// 12pt SF Pro Medium - Badges, tags
    static let caption = Font.caption.weight(.medium)
}
