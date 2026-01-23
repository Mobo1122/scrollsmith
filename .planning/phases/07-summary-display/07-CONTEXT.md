# Phase 7: Summary Display - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

iOS UI to display AI summaries in bullets, steps, and cards formats with deep-linking to source videos. Users can view summaries, switch formats, tap timestamps, and navigate to original content. This phase is display-only — editing summaries was Phase 5, subscriptions are Phase 8.

</domain>

<decisions>
## Implementation Decisions

### Summary Layout & Hierarchy

**Bullet summaries:**
- Claude decides numbered vs bulleted based on content type (sequential = numbered, categorical = bullets)

**Step-by-step checklists:**
- Timeline on left edge with dots showing visual progression
- Interactive checkboxes — users can mark steps complete for visual progress tracking
- Step completion state persists per video

**Swipeable cards:**
- Centered card with generous margins, shadow, and rounded corners ("grabbable" feel)
- 1-2 smaller, dimmed cards behind to hint at stack
- Entire card is interactive — no small buttons to hunt for
- Swipe directions: right = done/yes, left = skip/no (consistent across app)
- Mirror swipes with buttons at bottom for tap/keyboard users
- As card moves: subtle labels near edges ("Complete", "Skip") with matching colors (green/red) and rotation
- Smooth easing on release: fling off-screen if past threshold, snap back otherwise
- Brief toast after each swipe confirms action ("Step snoozed to tomorrow")

### Format Switching UX

- Segmented control at top: Bullets | Steps | Cards
- Hide unavailable segments (don't show format if video doesn't have it)
- Preserve scroll position when switching back to a format
- Default to "best available" — Steps if video is actionable, Bullets otherwise

### Deep-Linking Behavior

- Floating action button (FAB) for "View Original" — always accessible
- YouTube timestamps deep-link with `&t=` parameter to jump to that point
- Camera roll videos:
  - Inline player by default with thumbnail + play icon + duration
  - Basic controls only (play/pause, scrubber, mute) — preview feel
  - No autoplay — user explicitly starts playback
  - "Open in Photos" secondary action in overflow menu
- If original unavailable (deleted, private): show clear error message with reason if known

### Pro Tier Indicators

- Pro-only formats (Steps, Cards) appear as disabled segments with "Pro" badge
- Minimal persistent badges — only show Pro status when interacting with locked features
- Free users see first item of Pro format blurred as teaser + "See more with Pro"
- Tapping locked format shows:
  - Bottom sheet paywall (not full redirect)
  - Explains what Pro unlocks and how it helps
  - Two actions: "Upgrade to Pro" (primary) + "Not now" (secondary)
  - Contextual trigger only (not random)

### Claude's Discretion

- Exact typography, spacing, and visual hierarchy
- Animation durations and easing curves
- Card swipe threshold distances
- Toast/feedback timing
- Empty state illustrations
- Loading states during format switch

</decisions>

<specifics>
## Specific Ideas

- Cards should feel "grabbable" like Tinder but used for step completion
- Timeline dots on left edge for steps (like a checklist app)
- Blurred teaser approach for Pro features (show value before asking for upgrade)
- "No dead ends" — every upgrade prompt has a clear escape

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-summary-display*
*Context gathered: 2026-01-23*
