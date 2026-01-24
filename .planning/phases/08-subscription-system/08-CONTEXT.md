# Phase 8: Subscription System - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

RevenueCat integration with free/Pro tier enforcement, usage tracking, paywall UI, and in-app purchases. Users can subscribe to Pro via App Store, restore purchases, and see their usage limits. Backend verifies subscription status via webhooks.

</domain>

<decisions>
## Implementation Decisions

### Paywall Design
- Paywall appears on blocked actions + settings button + occasional "check out Pro" nudges after engagement
- Content: Free vs Pro side-by-side comparison table PLUS value-focused messaging (outcomes, not just features)
- Pro format teaser: Show first 1-2 items clearly, then blur remainder with upgrade CTA (sample peek pattern)
- Tone: FOMO-driven ("Don't miss out on step-by-step guides")

### Usage Indicator
- Primary placement: Usage pill in app header, visible from summary view without scrolling
- Pill is tappable → opens "Usage & Limits" sheet with current period details and upgrade options
- Format: Progress ring with number inside
- Color changes as usage increases: green → yellow → red
- Details screen: Current period only (usage count, reset date, upgrade button) — no history charts

### Upgrade Prompts
- At 10-video limit: Soft block — user can still add video but summary is locked until upgrade
- Locked state: Blurred summary with upgrade overlay (consistent with Pro format teasers)
- Additional trigger: After 5+ videos processed, show "Get more with Pro" banner
- Banner behavior: Dismissible for current session only (reappears next session)

### Pricing Display
- Plans: Monthly + Annual (annual at discount, approximately 2 months free)
- Free trial: 3-day trial before charging
- Discount framing: "Save Z%" badge next to annual plan name
- Annual microcopy: "Billed once per year, cancel anytime before renewal"
- Default selection: Annual pre-selected with "Best value" badge

### Claude's Discretion
- Exact pricing amounts (will be configured in App Store Connect)
- Animation and transition details for paywall presentation
- Specific copy variations within FOMO tone guidelines
- Progress ring sizing and color thresholds (e.g., yellow at 7, red at 9)

</decisions>

<specifics>
## Specific Ideas

- Usage pill should feel like a health indicator — quick glance shows status
- Soft block at limit keeps users engaged (they see their video saved, feel the value of upgrading)
- Sample peek for Pro features creates curiosity without being too aggressive
- Session-dismissible banner respects user autonomy while maintaining conversion touchpoints

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-subscription-system*
*Context gathered: 2026-01-24*
