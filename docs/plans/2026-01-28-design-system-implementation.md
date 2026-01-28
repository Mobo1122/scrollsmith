# Scrollsmith Design System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Scrollsmith from default SwiftUI styling to a polished, premium brand identity ready for App Store launch.

**Architecture:** Create a centralized theme system with design tokens (colors, typography, spacing), reusable styled components, and systematic application to all existing views. Font assets bundled in app, colors in Asset Catalog.

**Tech Stack:** SwiftUI, Asset Catalogs, Custom Fonts (Satoshi), SF Symbols

**Reference:** See [2026-01-28-brand-design-system.md](2026-01-28-brand-design-system.md) for complete design specifications.

---

## Task 1: Add Satoshi Font Assets

**Files:**
- Create: `ios/Scrollsmith/Resources/Fonts/Satoshi-Medium.otf`
- Create: `ios/Scrollsmith/Resources/Fonts/Satoshi-Bold.otf`
- Modify: `ios/Scrollsmith/Info.plist` (add font entries)

**Step 1: Create Fonts directory**

```bash
mkdir -p ios/Scrollsmith/Resources/Fonts
```

**Step 2: Download Satoshi font files**

Download from https://www.fontshare.com/fonts/satoshi
- Satoshi-Medium.otf
- Satoshi-Bold.otf

Place in `ios/Scrollsmith/Resources/Fonts/`

**Step 3: Add fonts to Xcode project**

In Xcode:
1. Right-click on `Scrollsmith` folder → Add Files
2. Select `Resources/Fonts` folder
3. Ensure "Copy items if needed" is checked
4. Ensure "Add to targets: Scrollsmith" is checked

**Step 4: Register fonts in Info.plist**

Add to Info.plist under root dict:
```xml
<key>UIAppFonts</key>
<array>
    <string>Satoshi-Medium.otf</string>
    <string>Satoshi-Bold.otf</string>
</array>
```

**Step 5: Verify fonts load**

Build and run. Add temporary test in any view:
```swift
Text("Test Satoshi")
    .font(.custom("Satoshi-Medium", size: 24))
```

**Step 6: Commit**

```bash
git add ios/Scrollsmith/Resources/Fonts ios/Scrollsmith/Info.plist
git commit -m "feat: add Satoshi font assets for brand typography"
```

---

## Task 2: Create Color Asset Catalog

**Files:**
- Modify: `ios/Scrollsmith/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `ios/Scrollsmith/Assets.xcassets/Colors/` (multiple colorsets)

**Step 1: Update AccentColor (Violet)**

Replace `ios/Scrollsmith/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.486",
          "green": "0.227",
          "blue": "0.929",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    },
    {
      "appearances": [
        {
          "appearance": "luminosity",
          "value": "dark"
        }
      ],
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.655",
          "green": "0.545",
          "blue": "0.980",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

**Step 2: Create Colors folder structure**

```bash
mkdir -p "ios/Scrollsmith/Assets.xcassets/Colors"
```

**Step 3: Create BackgroundPrimary.colorset**

Create `ios/Scrollsmith/Assets.xcassets/Colors/BackgroundPrimary.colorset/Contents.json`:

```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "1.000",
          "green": "1.000",
          "blue": "1.000",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    },
    {
      "appearances": [
        {
          "appearance": "luminosity",
          "value": "dark"
        }
      ],
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.059",
          "green": "0.059",
          "blue": "0.059",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

**Step 4: Create BackgroundSecondary.colorset**

Create `ios/Scrollsmith/Assets.xcassets/Colors/BackgroundSecondary.colorset/Contents.json`:

```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.976",
          "green": "0.980",
          "blue": "0.984",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    },
    {
      "appearances": [
        {
          "appearance": "luminosity",
          "value": "dark"
        }
      ],
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.102",
          "green": "0.102",
          "blue": "0.102",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

**Step 5: Create BackgroundTertiary.colorset**

Create `ios/Scrollsmith/Assets.xcassets/Colors/BackgroundTertiary.colorset/Contents.json`:

```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.953",
          "green": "0.957",
          "blue": "0.965",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    },
    {
      "appearances": [
        {
          "appearance": "luminosity",
          "value": "dark"
        }
      ],
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.149",
          "green": "0.149",
          "blue": "0.149",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

**Step 6: Create semantic color sets (Success, Warning, Error)**

Create `ios/Scrollsmith/Assets.xcassets/Colors/Success.colorset/Contents.json`:
```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.063",
          "green": "0.725",
          "blue": "0.506",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

Create `ios/Scrollsmith/Assets.xcassets/Colors/Warning.colorset/Contents.json`:
```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.961",
          "green": "0.620",
          "blue": "0.043",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

Create `ios/Scrollsmith/Assets.xcassets/Colors/Error.colorset/Contents.json`:
```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.937",
          "green": "0.267",
          "blue": "0.267",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

**Step 7: Verify colors in Xcode**

Open Xcode, navigate to Assets.xcassets, verify all colorsets appear with correct light/dark variants.

**Step 8: Commit**

```bash
git add ios/Scrollsmith/Assets.xcassets/
git commit -m "feat: add brand color palette to asset catalog"
```

---

## Task 3: Create Theme System (Design Tokens)

**Files:**
- Create: `ios/Scrollsmith/Theme/Theme.swift`
- Create: `ios/Scrollsmith/Theme/Typography.swift`
- Create: `ios/Scrollsmith/Theme/Spacing.swift`

**Step 1: Create Theme directory**

```bash
mkdir -p ios/Scrollsmith/Theme
```

**Step 2: Create Typography.swift**

Create `ios/Scrollsmith/Theme/Typography.swift`:

```swift
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
```

**Step 3: Create Spacing.swift**

Create `ios/Scrollsmith/Theme/Spacing.swift`:

```swift
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
```

**Step 4: Create Theme.swift**

Create `ios/Scrollsmith/Theme/Theme.swift`:

```swift
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
```

**Step 5: Add Theme folder to Xcode project**

In Xcode, add the Theme folder to the project.

**Step 6: Build and verify**

Build the project to ensure no compilation errors.

**Step 7: Commit**

```bash
git add ios/Scrollsmith/Theme/
git commit -m "feat: add design system tokens (typography, spacing, theme)"
```

---

## Task 4: Create Styled Button Components

**Files:**
- Create: `ios/Scrollsmith/Theme/Components/StyledButton.swift`

**Step 1: Create Components directory**

```bash
mkdir -p ios/Scrollsmith/Theme/Components
```

**Step 2: Create StyledButton.swift**

Create `ios/Scrollsmith/Theme/Components/StyledButton.swift`:

```swift
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
```

**Step 3: Build and verify preview**

Open preview in Xcode Canvas to verify button styles.

**Step 4: Commit**

```bash
git add ios/Scrollsmith/Theme/Components/
git commit -m "feat: add styled button components"
```

---

## Task 5: Create Styled Card Component

**Files:**
- Create: `ios/Scrollsmith/Theme/Components/StyledCard.swift`

**Step 1: Create StyledCard.swift**

Create `ios/Scrollsmith/Theme/Components/StyledCard.swift`:

```swift
import SwiftUI

/// A styled card container with consistent appearance.
struct StyledCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.cardPadding)
            .background(Theme.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .shadow(
                color: colorScheme == .light ? Theme.cardShadow.color : .clear,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
    }
}

/// Card modifier for applying card styling to any view.
struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .background(Theme.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .shadow(
                color: colorScheme == .light ? Theme.cardShadow.color : .clear,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
    }
}

extension View {
    /// Apply card styling to any view.
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Preview

#Preview("Card Styles") {
    VStack(spacing: 24) {
        StyledCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Title")
                    .font(Typography.title3)
                Text("Card content goes here with some descriptive text.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.Text.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        HStack {
            Text("Using modifier")
            Spacer()
            Image(systemName: "chevron.right")
        }
        .cardStyle()
    }
    .padding()
    .background(Theme.Background.primary)
}
```

**Step 2: Build and verify preview**

**Step 3: Commit**

```bash
git add ios/Scrollsmith/Theme/Components/StyledCard.swift
git commit -m "feat: add styled card component"
```

---

## Task 6: Create Styled Input Component

**Files:**
- Create: `ios/Scrollsmith/Theme/Components/StyledTextField.swift`

**Step 1: Create StyledTextField.swift**

Create `ios/Scrollsmith/Theme/Components/StyledTextField.swift`:

```swift
import SwiftUI

/// A styled text field with consistent appearance.
struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(Typography.body)
        .padding(.horizontal, Spacing.md)
        .frame(height: Spacing.inputHeight)
        .background(Theme.Background.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                .stroke(isFocused ? Theme.accent : .clear, lineWidth: 2)
        )
        .focused($isFocused)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Preview

#Preview("Text Fields") {
    VStack(spacing: 16) {
        StyledTextField(placeholder: "Email", text: .constant(""))
        StyledTextField(placeholder: "Password", text: .constant(""), isSecure: true)
        StyledTextField(placeholder: "With text", text: .constant("hello@example.com"))
    }
    .padding()
}
```

**Step 2: Build and verify preview**

**Step 3: Commit**

```bash
git add ios/Scrollsmith/Theme/Components/StyledTextField.swift
git commit -m "feat: add styled text field component"
```

---

## Task 7: Create Tag/Chip Component

**Files:**
- Create: `ios/Scrollsmith/Theme/Components/TagView.swift`

**Step 1: Create TagView.swift**

Create `ios/Scrollsmith/Theme/Components/TagView.swift`:

```swift
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
```

**Step 2: Build and verify preview**

**Step 3: Commit**

```bash
git add ios/Scrollsmith/Theme/Components/TagView.swift
git commit -m "feat: add tag/chip component"
```

---

## Task 8: Create Screen Title View

**Files:**
- Create: `ios/Scrollsmith/Theme/Components/ScreenTitle.swift`

**Step 1: Create ScreenTitle.swift**

Create `ios/Scrollsmith/Theme/Components/ScreenTitle.swift`:

```swift
import SwiftUI

/// Large screen title using Satoshi font.
///
/// Use this instead of `.navigationTitle()` for custom branded headers.
struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.largeTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading) {
        ScreenTitle(text: "Playbooks")

        Text("Content goes here")
            .padding(.horizontal)
    }
}
```

**Step 2: Build and verify preview**

**Step 3: Commit**

```bash
git add ios/Scrollsmith/Theme/Components/ScreenTitle.swift
git commit -m "feat: add screen title component with Satoshi font"
```

---

## Task 9: Update MainTabView with Theme

**Files:**
- Modify: `ios/Scrollsmith/Views/MainTabView.swift`

**Step 1: Read current file**

Read the current MainTabView.swift to understand structure.

**Step 2: Update with themed tab bar**

Update `ios/Scrollsmith/Views/MainTabView.swift`:

```swift
import SwiftUI

/// Main tab bar view for authenticated users.
///
/// Provides navigation between Home, Capture, Habits, and Settings tabs.
struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var uploadQueueService: UploadQueueService

    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "Home"
        case capture = "Capture"
        case habits = "Habits"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home:
                return "book.closed"
            case .capture:
                return "plus.circle.fill"
            case .habits:
                return "checkmark.circle"
            case .settings:
                return "gearshape"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PlaybookListView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            CaptureView()
                .tabItem {
                    Label(Tab.capture.rawValue, systemImage: Tab.capture.icon)
                }
                .tag(Tab.capture)
                .badge(uploadQueueService.pendingCount)

            HabitListView()
                .tabItem {
                    Label(Tab.habits.rawValue, systemImage: Tab.habits.icon)
                }
                .tag(Tab.habits)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(Theme.accent)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionViewModel())
        .environmentObject(UploadQueueService.shared)
}
```

**Step 3: Build and verify**

Build and run to confirm tab bar uses violet accent.

**Step 4: Commit**

```bash
git add ios/Scrollsmith/Views/MainTabView.swift
git commit -m "feat: apply theme accent color to tab bar"
```

---

## Task 10: Update PlaybookListView with Design System

**Files:**
- Modify: `ios/Scrollsmith/Views/Playbooks/PlaybookListView.swift`

**Step 1: Update PlaybookListView with themed components**

This is a larger refactor. Update `ios/Scrollsmith/Views/Playbooks/PlaybookListView.swift` to:
- Use `ScreenTitle` instead of `.navigationTitle()`
- Use `StyledCard` for playbook rows
- Apply `Typography` to text elements
- Use `Theme` colors throughout
- Add proper spacing with `Spacing` constants

The full implementation should follow the design spec:
- Custom header with Satoshi title
- Card-based playbook items (not list rows)
- Thumbnail grid on left (2×2 preview)
- Violet accent for icons
- Proper empty state

**Step 2: Build and test**

**Step 3: Commit**

```bash
git add ios/Scrollsmith/Views/Playbooks/PlaybookListView.swift
git commit -m "feat: apply design system to PlaybookListView"
```

---

## Task 11-16: Apply Design System to Remaining Views

Apply the same pattern to:
- **Task 11:** `PlaybookDetailView.swift`
- **Task 12:** `CaptureView.swift` + related sheets
- **Task 13:** `HabitListView.swift` + `HabitRowView.swift`
- **Task 14:** `HabitDetailView.swift` + `StreakCalendarView.swift`
- **Task 15:** `SummaryDisplayView.swift` + format views
- **Task 16:** `SettingsView.swift` + `ScrollsmithPaywallView.swift`

Each task follows the same pattern:
1. Read current implementation
2. Apply Theme colors, Typography, Spacing
3. Replace default components with styled versions
4. Build and verify
5. Commit with descriptive message

---

## Task 17: Add Habit Completion Animation

**Files:**
- Modify: `ios/Scrollsmith/Views/Habits/HabitRowView.swift`

**Step 1: Add completion animation**

Add satisfying animation when habit is completed:
- Checkbox fills with violet
- Scale bounce (1.0 → 1.1 → 1.0)
- Checkmark draws on with spring
- Haptic feedback (success)

**Step 2: Build and test**

**Step 3: Commit**

```bash
git add ios/Scrollsmith/Views/Habits/HabitRowView.swift
git commit -m "feat: add delightful habit completion animation"
```

---

## Task 18: Add Processing Complete Animation

**Files:**
- Modify: `ios/Scrollsmith/Views/Capture/UploadProgressView.swift`

**Step 1: Add completion animation**

Add violet glow pulse when video processing completes.

**Step 2: Build and test**

**Step 3: Commit**

---

## Task 19: Generate App Icon

**Files:**
- Modify: `ios/Scrollsmith/Assets.xcassets/AppIcon.appiconset/`

**Step 1: Use ios-app-icon-generator skill**

Invoke the skill to generate app icon with:
- Mark: Abstract scroll/playbook shape
- Background: Violet gradient (#7C3AED → #5B21B6)
- Style: Clean, geometric

**Step 2: Export all sizes and add to asset catalog**

**Step 3: Commit**

```bash
git add ios/Scrollsmith/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat: add Scrollsmith app icon"
```

---

## Task 20: Generate Custom Icons

**Files:**
- Create: `ios/Scrollsmith/Assets.xcassets/Icons/`

**Step 1: Use asset-generator skill**

Generate custom icons:
- Playbook icon
- Habit/Streak icon
- Summary format icons (bullets, steps, cards)
- Video source icons (YouTube, camera roll, TikTok)
- Pro badge

**Step 2: Add to asset catalog**

**Step 3: Commit**

```bash
git add ios/Scrollsmith/Assets.xcassets/Icons/
git commit -m "feat: add custom Scrollsmith iconography"
```

---

## Task 21: Create Onboarding Flow

**Files:**
- Create: `ios/Scrollsmith/Views/Onboarding/OnboardingView.swift`
- Create: `ios/Scrollsmith/Views/Onboarding/OnboardingPageView.swift`
- Modify: `ios/Scrollsmith/ContentView.swift`

**Step 1: Create onboarding screens**

3-screen horizontal swipe:
1. "Capture Your Inspiration"
2. "Get Actionable Summaries"
3. "Build Real Habits"

**Step 2: Add first-launch check**

Track in UserDefaults, show onboarding before auth.

**Step 3: Build and test full flow**

**Step 4: Commit**

```bash
git add ios/Scrollsmith/Views/Onboarding/
git add ios/Scrollsmith/ContentView.swift
git commit -m "feat: add branded onboarding flow"
```

---

## Task 22: Final Polish Pass

**Files:**
- All view files

**Step 1: Audit all screens**

Check every screen for:
- Consistent use of Typography
- Correct Spacing values
- Theme colors throughout
- Dark mode appearance
- Accessibility (Dynamic Type)

**Step 2: Fix any inconsistencies**

**Step 3: Test on multiple devices/modes**

- iPhone SE (small)
- iPhone 15 Pro (standard)
- iPhone 15 Pro Max (large)
- Light mode
- Dark mode
- Large text

**Step 4: Final commit**

```bash
git add .
git commit -m "chore: design system polish pass"
```

---

## Summary

Total tasks: 22
Estimated implementation: Systematic, one task at a time

**Implementation order:**
1. Foundation (Tasks 1-3): Fonts, colors, theme tokens
2. Components (Tasks 4-8): Buttons, cards, inputs, tags
3. Application (Tasks 9-16): Apply to all screens
4. Animation (Tasks 17-18): Delightful moments
5. Assets (Tasks 19-20): App icon, custom icons
6. Onboarding (Task 21): First-launch experience
7. Polish (Task 22): Final audit

Each task is atomic and committable. Build after every step to catch issues early.
