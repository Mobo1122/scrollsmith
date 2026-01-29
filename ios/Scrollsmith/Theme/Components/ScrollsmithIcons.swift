import SwiftUI

/// Custom iconography for Scrollsmith.
///
/// Icons follow a consistent style:
/// - Stroke weight: 1.5pt equivalent
/// - Corner radius: 2pt
/// - Cap style: Round
///
/// Most icons use SF Symbols for native feel, with custom shapes where needed.
enum ScrollsmithIcons {

    // MARK: - Tab Bar Icons

    /// Playbook icon - stacked rectangles with bookmark feel.
    /// Uses SF Symbol for native tab bar appearance.
    static let playbook = "book.closed"
    static let playbookFill = "book.closed.fill"

    /// Capture icon - circle with plus.
    static let capture = "plus.circle"
    static let captureFill = "plus.circle.fill"

    /// Habits icon - checkmark with circle.
    static let habits = "checkmark.circle"
    static let habitsFill = "checkmark.circle.fill"

    /// Settings icon - gear.
    static let settings = "gearshape"
    static let settingsFill = "gearshape.fill"

    // MARK: - Summary Format Icons

    /// Bullet summary - lines with dots.
    static let bulletSummary = "list.bullet"

    /// Step summary - numbered list.
    static let stepSummary = "list.number"

    /// Card summary - stacked cards.
    static let cardSummary = "square.stack"

    // MARK: - Source Attribution Icons

    /// YouTube - play button in rounded rect.
    static let youtube = "play.rectangle.fill"

    /// Camera roll - photo library.
    static let cameraRoll = "photo.on.rectangle"

    /// TikTok - music note with play.
    static let tiktok = "music.note"

    /// Instagram - camera.
    static let instagram = "camera"

    /// Generic link/URL.
    static let link = "link"

    // MARK: - Streak & Achievement Icons

    /// Flame for streak display.
    static let streak = "flame.fill"

    /// Checkmark for completion.
    static let complete = "checkmark"

    /// Sparkle for pro/premium.
    static let pro = "sparkles"

    // MARK: - Action Icons

    /// Share.
    static let share = "square.and.arrow.up"

    /// Edit.
    static let edit = "pencil"

    /// Delete.
    static let delete = "trash"

    /// Add.
    static let add = "plus"

    /// Close/dismiss.
    static let close = "xmark"

    /// Chevron right for navigation.
    static let chevronRight = "chevron.right"

    /// Chevron down for expansion.
    static let chevronDown = "chevron.down"
}

// MARK: - Custom Icon Views

/// A custom playbook icon with stacked rectangles and bookmark tab.
struct PlaybookIconView: View {
    var size: CGFloat = 24
    var color: Color = Theme.accent

    var body: some View {
        ZStack {
            // Back rectangle
            RoundedRectangle(cornerRadius: 2)
                .stroke(color, lineWidth: 1.5)
                .frame(width: size * 0.65, height: size * 0.85)
                .offset(x: size * 0.08, y: -size * 0.04)

            // Front rectangle with bookmark notch
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: size * 0.65, height: size * 0.85)

                // Bookmark tab
                Path { path in
                    let tabWidth = size * 0.15
                    let tabHeight = size * 0.25
                    let startX = size * 0.65 - size * 0.12

                    path.move(to: CGPoint(x: startX, y: 0))
                    path.addLine(to: CGPoint(x: startX + tabWidth, y: 0))
                    path.addLine(to: CGPoint(x: startX + tabWidth, y: tabHeight))
                    path.addLine(to: CGPoint(x: startX + tabWidth / 2, y: tabHeight * 0.7))
                    path.addLine(to: CGPoint(x: startX, y: tabHeight))
                    path.closeSubpath()
                }
                .fill(color)
            }
            .offset(x: -size * 0.08, y: size * 0.04)
        }
        .frame(width: size, height: size)
    }
}

/// A flame icon with checkmark overlay for habit streaks.
struct HabitStreakIcon: View {
    var size: CGFloat = 24
    var streakColor: Color = Theme.Semantic.warning
    var checkColor: Color = Theme.Semantic.success

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.8))
                .foregroundColor(streakColor)

            Image(systemName: "checkmark")
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundColor(.white)
                .offset(y: size * 0.05)
        }
        .frame(width: size, height: size)
    }
}

/// Pro badge with sparkle icon and gradient background.
struct ProBadgeIcon: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Capsule()
                .fill(Theme.proGradient)
                .frame(width: size * 2.2, height: size)

            HStack(spacing: 2) {
                Image(systemName: ScrollsmithIcons.pro)
                    .font(.system(size: size * 0.5))
                Text("PRO")
                    .font(.system(size: size * 0.5, weight: .bold))
            }
            .foregroundColor(.white)
        }
    }
}

/// Lock icon for premium-locked content.
struct ProLockIcon: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.15))
                .frame(width: size * 1.5, height: size * 1.5)

            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.6))
                .foregroundColor(Theme.accent)
        }
    }
}

/// Video source icon based on platform.
struct VideoSourceIcon: View {
    let platform: VideoPlatform
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.8))
            .foregroundColor(platformColor)
            .frame(width: size, height: size)
    }

    private var iconName: String {
        switch platform {
        case .youtube: return ScrollsmithIcons.youtube
        case .tiktok: return ScrollsmithIcons.tiktok
        case .instagram: return ScrollsmithIcons.instagram
        case .cameraRoll: return ScrollsmithIcons.cameraRoll
        case .unknown: return ScrollsmithIcons.link
        }
    }

    private var platformColor: Color {
        switch platform {
        case .youtube: return .red
        case .tiktok: return .pink
        case .instagram: return .purple
        case .cameraRoll: return Theme.accent
        case .unknown: return Theme.Text.secondary
        }
    }
}

/// Summary format icon for the format toggle.
struct SummaryFormatIcon: View {
    enum Format {
        case bullets
        case steps
        case cards
    }

    let format: Format
    var size: CGFloat = 20
    var isSelected: Bool = false

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.8))
            .foregroundColor(isSelected ? Theme.accent : Theme.Text.secondary)
            .frame(width: size, height: size)
    }

    private var iconName: String {
        switch format {
        case .bullets: return ScrollsmithIcons.bulletSummary
        case .steps: return ScrollsmithIcons.stepSummary
        case .cards: return ScrollsmithIcons.cardSummary
        }
    }
}

// MARK: - Previews

#Preview("Tab Bar Icons") {
    HStack(spacing: 32) {
        VStack {
            Image(systemName: ScrollsmithIcons.playbookFill)
            Text("Playbooks").font(.caption)
        }
        VStack {
            Image(systemName: ScrollsmithIcons.captureFill)
            Text("Capture").font(.caption)
        }
        VStack {
            Image(systemName: ScrollsmithIcons.habitsFill)
            Text("Habits").font(.caption)
        }
        VStack {
            Image(systemName: ScrollsmithIcons.settingsFill)
            Text("Settings").font(.caption)
        }
    }
    .foregroundColor(Theme.accent)
    .font(.title2)
    .padding()
}

#Preview("Custom Icons") {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            PlaybookIconView(size: 32)
            HabitStreakIcon(size: 32)
        }

        HStack(spacing: 16) {
            ProBadgeIcon()
            ProLockIcon()
        }

        HStack(spacing: 16) {
            VideoSourceIcon(platform: .youtube)
            VideoSourceIcon(platform: .tiktok)
            VideoSourceIcon(platform: .instagram)
            VideoSourceIcon(platform: .cameraRoll)
        }

        HStack(spacing: 16) {
            SummaryFormatIcon(format: .bullets, isSelected: true)
            SummaryFormatIcon(format: .steps)
            SummaryFormatIcon(format: .cards)
        }
    }
    .padding()
}
