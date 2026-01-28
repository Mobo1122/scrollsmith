# Scrollsmith Brand & Design System

**Status:** Approved
**Created:** 2026-01-28
**Purpose:** Complete visual identity and UI design for App Store launch

---

## Brand Identity

### Personality
**Clean & premium** — Refined aesthetics, subtle animations, feels like a high-end productivity tool worth paying for.

### Core Values
- Premium through restraint, not flashiness
- ADHD-friendly: scannable, forgiving, rewarding
- Transformation narrative: chaos → clarity → action

### Reference
Readwise Reader — sophisticated, minimalist, calm focus, premium tool aesthetic.

---

## Color System

### Primary Accent: Violet

| Mode | Hex | Usage |
|------|-----|-------|
| Light | `#7C3AED` | Primary actions, active states, brand accent |
| Dark | `#A78BFA` | Softer for dark backgrounds, maintains visibility |

### Backgrounds

| Surface | Light Mode | Dark Mode |
|---------|------------|-----------|
| Primary | `#FFFFFF` | `#0F0F0F` |
| Secondary | `#F9FAFB` | `#1A1A1A` |
| Tertiary | `#F3F4F6` | `#262626` |

### Text

| Level | Light Mode | Dark Mode |
|-------|------------|-----------|
| Primary | `#111827` | `#F9FAFB` |
| Secondary | `#6B7280` | `#9CA3AF` |
| Tertiary | `#9CA3AF` | `#6B7280` |

### Semantic Colors

| Purpose | Color | Hex |
|---------|-------|-----|
| Success | Green | `#10B981` |
| Warning | Amber | `#F59E0B` |
| Error | Red | `#EF4444` |
| Pro/Premium | Violet gradient | `#7C3AED → #5B21B6` |

### Surface Treatment
- Cards use secondary background with subtle elevation
- No harsh borders — separation through shadow and background contrast
- Shadows (light mode only): `0 1px 3px rgba(0,0,0,0.08)`

---

## Typography

### Fonts

| Type | Font | Usage |
|------|------|-------|
| Display | Satoshi | Screen titles, section headers, empty states, onboarding |
| Body | SF Pro | All body text, buttons, labels, captions, metadata |

### Type Scale

| Name | Size | Weight | Font | Usage |
|------|------|--------|------|-------|
| largeTitle | 34pt | Bold | Satoshi | Screen titles |
| title | 28pt | Medium | Satoshi | Section headers, sheet titles |
| title3 | 20pt | Medium | Satoshi | Card titles, playbook names |
| headline | 17pt | Semibold | SF Pro | List item titles, video names |
| body | 17pt | Regular | SF Pro | Primary content, summaries |
| callout | 16pt | Regular | SF Pro | Secondary content |
| subheadline | 15pt | Regular | SF Pro | Metadata, timestamps |
| footnote | 13pt | Regular | SF Pro | Captions, hints |
| caption | 12pt | Medium | SF Pro | Badges, tags, labels |

### Spacing
- Line height: 1.5× for body (ADHD readability), 1.2× for headlines
- Letter spacing: -0.5% for Satoshi headers, default for SF Pro

---

## Components

### Buttons

| Type | Style | Usage |
|------|-------|-------|
| Primary | Solid violet fill, white text, 12pt radius | Main CTAs |
| Secondary | Violet text, violet/10% background | Secondary actions |
| Ghost | Violet text only | Tertiary actions, links |
| Destructive | Red text, red/10% background | Delete, remove |

- Minimum tap height: 50pt
- Press animation: Scale to 0.97

### Cards

- Background: Secondary surface
- Corner radius: 16pt
- Shadow (light): `0 1px 3px rgba(0,0,0,0.08)`
- Shadow (dark): None — use background contrast
- Padding: 16pt internal

### Inputs

- Height: 48pt
- Corner radius: 12pt
- Background: Tertiary surface
- Focus state: 2pt violet ring

### Tags/Chips

- Padding: 8pt vertical, 12pt horizontal
- Background: Violet/10%
- Text: Violet
- Corner radius: Full (pill)

### Dividers

- Use sparingly — prefer spacing
- When needed: 1pt, 5% opacity

---

## Screen Designs

### Navigation (Tab Bar)

- Standard iOS tab bar with blur
- Active: Violet icon + label
- Inactive: Secondary text color
- Tabs: Playbooks, Capture, Habits, Settings

### Playbooks List (Home)

- Large title "Playbooks" (Satoshi Bold)
- Search bar: Pill-shaped, appears on scroll
- Usage pill: Top-right "3/10 videos" for free tier
- Playbook cards: Full-width, thumbnail grid left, name + count + date right
- Empty state: Centered illustration + headline + CTA

### Playbook Detail

- Back button + title in nav bar
- Editable playbook name
- Horizontal scrolling tag pills
- Video cards: Thumbnail, title, source icon, summary preview
- Swipe to delete, long-press to reorder

### Video Summary

- Close (X) top-left, share top-right
- Inline video player (16:9, 12pt radius)
- Source attribution bar (for URL videos):
  - Creator avatar/platform icon
  - Creator name
  - "View Original" ghost button
- Summary format tabs: Bullets | Steps | Cards
  - Locked formats show Pro icon
- Bullet summary: Violet bullet points, generous spacing, timestamp links
- Step checklist: Numbered, expandable, checkboxes
- Swipeable cards: Horizontal swipe, page indicators

### Capture Tab

- Large title "Capture"
- Three input cards:
  - Camera Roll: "Choose from library"
  - Paste URL: "Paste video URL"
  - Share Extension: "Share from any app" (informational)
- Pending uploads section with progress cards

### URL Input Sheet

- Half-sheet modal
- Large text field, paste button
- URL validation indicator
- Platform auto-detection chip

### Video Confirmation Sheet

- Large preview thumbnail
- Title, duration, source
- Playbook picker dropdown
- Cancel + Start Processing buttons

### Processing State

- Card shows stages: Uploading → Transcribing → Summarizing → Done
- Checkmark animation per stage
- Completion: Violet glow pulse

### Habits List

- Large title "Habits"
- Streak summary bar: Count + flame icon, violet tint
- Today section: Due habits with large checkboxes
- Completed section: Collapsed, dimmed
- All habits: Grouped by frequency

### Habit Detail

- Habit name (editable)
- Source video card
- Streak calendar (month grid, violet fills)
- Stats: Current streak, longest, completion rate
- Reminder settings
- Edit + Delete actions

### Habit Extraction Sheet

- AI-suggested habits (1-3) as selectable cards
- Habit name, frequency, "Why" explanation
- Editable before saving

### Settings

- Profile section: Avatar, name, email, subscription badge
- Grouped sections: Account, Preferences, Support, Legal
- About: Version number

### Pro Paywall

- Full-screen sheet
- Headline: "Unlock Scrollsmith Pro"
- Feature comparison with checkmarks
- Pricing cards: Monthly, Yearly (with save badge)
- CTA + Restore purchases link
- Always dismissible (X button)

### Onboarding (3 screens)

1. "Capture Your Inspiration" — videos flowing into funnel
2. "Get Actionable Summaries" — video → bullet points
3. "Build Real Habits" — checkmarks, streaks

### Authentication

- Apple Sign In (first position)
- "or" divider
- Email option
- Clean single-field progression
- Terms & Privacy footer

### Post-Auth

- Optional name input
- Notification permission (custom screen before system prompt)

---

## Animation

### Purposeful Motion

| Action | Animation | Duration | Curve |
|--------|-----------|----------|-------|
| Screen push | Horizontal slide | 350ms | ease-in-out |
| Sheet present | Slide up | 300ms | spring (0.8) |
| Tab switch | Cross-fade | 200ms | ease-out |
| Card tap | Scale 0.97 → 1.0 | 150ms | spring |
| List appear | Fade + slide (staggered) | 250ms | ease-out |
| Progress fill | Width animation | continuous | linear |

### Delightful Moments

| Trigger | Animation |
|---------|-----------|
| Habit completed | Checkbox fills, checkmark draws, scale bounce, haptic |
| Streak milestone | Violet particle burst, number glow |
| Video complete | Card violet glow pulse (2×) |
| First video | Sparkle effect |
| Playbook created | Spring bounce-in |

### Micro-interactions

- Buttons: Scale 0.97 on press
- Toggles: Bounce at endpoints
- Pull to refresh: Violet spinner
- Swipe to delete: Smooth red reveal, haptic at threshold
- Long press: Scale down + haptic → context menu

### Loading States

- Skeleton screens (not spinners)
- Subtle shimmer animation
- Violet spinner only for <2s waits

---

## Iconography

### Style

- Stroke weight: 1.5pt
- Corner radius: 2pt
- Cap style: Round
- Grid: 24×24pt (20×20pt live area)

### Custom Icons

| Icon | Description | Usage |
|------|-------------|-------|
| Playbook | Stacked rectangles with bookmark | Tab bar, lists |
| Capture | Circle with plus | Tab bar |
| Habit/Streak | Checkmark with flame | Tab bar, cards |
| Bullet summary | Lines with dots | Format toggle |
| Step summary | Numbered list | Format toggle |
| Card summary | Stacked offset cards | Format toggle |
| YouTube | Play in rounded rect | Source attribution |
| Camera roll | Film frame | Source attribution |
| TikTok | Musical note + play | Source attribution |
| Pro badge | Sparkle/star | Paywall, locks |

### States

- Default: Primary text color
- Active: Violet accent
- Disabled: 40% opacity
- Selected: Violet fill/stroke

### App Icon

- Mark: Abstract "S" or scroll/playbook shape
- Background: Violet gradient (light top → dark bottom)
- Style: Clean, geometric, recognizable at small sizes
- No text

---

## ADHD-Friendly Design Principles

1. **Large tap targets** — 50pt buttons, 44pt checkboxes
2. **Generous spacing** — 1.5× line height, ample padding
3. **Scannable content** — Clear hierarchy, bullet points
4. **Skeleton loading** — No anxiety-inducing spinners
5. **Streak forgiveness** — Visible in calendar, not punitive
6. **Dopamine moments** — Celebrations on completions
7. **No dark patterns** — Paywall is value-focused, always dismissible

---

## Implementation Order

1. **Color system** — Define SwiftUI Color extensions
2. **Typography** — Create Satoshi font assets, type scale
3. **Core components** — Buttons, cards, inputs
4. **App icon** — Using ios-app-icon-generator skill
5. **Custom icons** — Using asset-generator skill
6. **Screen updates** — Apply design system to existing views
7. **Animations** — Add motion design
8. **Onboarding** — New flow with illustrations

---

*Design approved: 2026-01-28*
