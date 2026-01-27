# Phase 12: Legal & Launch Prep - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Prepare legal documents (Terms of Service, Privacy Policy) and App Store submission materials for v1 launch. Includes hosting legal docs, adding links to iOS app, and creating marketing assets. Does not include post-launch analytics, A/B testing, or marketing campaigns.

</domain>

<decisions>
## Implementation Decisions

### Legal document style
- Standard legal language (traditional terms, defined sections)
- AI/LLM processing: brief mention in data processing section (not a dedicated AI section)
- Jurisdiction: England & Wales
- Data collection disclosure format: Claude's discretion

### Document hosting
- Static HTML pages served by FastAPI at `/terms` and `/privacy` endpoints
- iOS opens legal docs in in-app WebView (sheet, not external Safari)
- Legal links appear in: signup screen footer, Settings, and new About screen
- Signup screen: footer text "By signing up, you agree to our Terms and Privacy Policy" with inline links (no checkbox)

### App Store presentation
- Screenshots: device frames with headline captions above each screen
- Description tone: problem-focused opening ("Saved 100 videos but watched none?") leading into benefit-focused resolution
- Preview video: yes, animated promo with motion graphics and app screens (not screen recording)
- Screenshot feature order: Claude's discretion based on conversion patterns

### Support & contact
- Support email: hello@scrollsmith.app
- Email displayed in: Settings and About screen
- Tap action: opens Mail compose sheet with pre-filled subject line
- No auto-diagnostic info in email body

### Claude's Discretion
- Data disclosure format (category-based vs comprehensive list)
- Screenshot feature order and captions
- About screen layout and content
- Specific Terms and Privacy Policy clauses (standard for subscription apps)

</decisions>

<specifics>
## Specific Ideas

- Jurisdiction explicitly England & Wales for legal clarity
- Problem-focused hook in App Store description ("Saved 100 videos but watched none?")
- Animated promo video rather than screen recording for more polished presentation
- About screen added (wasn't in original plans) - contains legal links, version info, support

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-legal-launch-prep*
*Context gathered: 2026-01-27*
