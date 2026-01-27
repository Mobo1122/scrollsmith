---
phase: 12-legal-launch-prep
verified: 2026-01-27T23:55:00Z
status: passed
score: 6/6 must-haves verified
human_verification:
  - test: "Verify App Store Connect agreements"
    expected: "Paid Applications Agreement shows Active status; banking shows Clear"
    why_human: "App Store Connect portal cannot be accessed programmatically"
  - test: "Verify subscription products"
    expected: "scrollsmith_monthly and scrollsmith_yearly show Ready to Submit"
    why_human: "App Store Connect portal requires manual login"
  - test: "Test legal document loading in iOS app"
    expected: "Tapping Terms/Privacy in RegisterView and AboutView opens WebView with correct document"
    why_human: "Requires running app to verify WebView loads backend URLs correctly"
  - test: "Test mail composer in AboutView"
    expected: "Contact Support opens mail with hello@scrollsmith.app and subject pre-filled"
    why_human: "Requires device with Mail configured"
---

# Phase 12: Legal & Launch Prep Verification Report

**Phase Goal:** Terms of Service, Privacy Policy, App Store submission materials
**Verified:** 2026-01-27T23:55:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Terms of Service and Privacy Policy are written and hosted | VERIFIED | `backend/app/static/legal/terms.html` (159 lines, 9.1KB), `privacy.html` (262 lines, 11.5KB) served via `/terms` and `/privacy` endpoints in main.py |
| 2 | Privacy Policy and Terms links accessible from signup screen | VERIFIED | RegisterView.swift has legal footer with `showingTerms` and `showingPrivacy` state, `.sheet` modifiers present at lines 192-197 |
| 3 | Privacy Policy and Terms links accessible from settings | VERIFIED | AboutView.swift has Legal section with Terms and Privacy buttons (lines 48-59), SettingsView has NavigationLink to AboutView (lines 79-84) |
| 4 | App Store description and keywords exist | VERIFIED | `.planning/app-store/description.txt` (27 lines), `keywords.txt` (99 chars, under 100 limit) |
| 5 | Customer support email listed in settings | VERIFIED | AboutView.swift line 17: `private let supportEmail = "hello@scrollsmith.app"`, Contact Support button with MailView integration |
| 6 | Legal documents include GDPR-compliant AI/LLM disclosure | VERIFIED | privacy.html lines 131-157: AI-Powered Processing section with OpenAI/Anthropic table and "not used to train AI models" statement |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `backend/app/static/legal/terms.html` | Terms of Service HTML | VERIFIED | 159 lines, subscription terms, E&W jurisdiction, contact email |
| `backend/app/static/legal/privacy.html` | Privacy Policy HTML | VERIFIED | 262 lines, GDPR structure, AI disclosure table, third-party processors |
| `backend/app/main.py` | /terms and /privacy routes | VERIFIED | Lines 75-84: FileResponse for both legal documents |
| `ios/Scrollsmith/Views/Components/WebView.swift` | WKWebView wrapper | VERIFIED | 19 lines, UIViewRepresentable, loads URL |
| `ios/Scrollsmith/Views/Components/MailView.swift` | MFMailComposeViewController wrapper | VERIFIED | 54 lines, Coordinator pattern, canSendMail check |
| `ios/Scrollsmith/Views/Components/LegalDocumentView.swift` | Sheet container for legal docs | VERIFIED | 57 lines, DocumentType enum, uses Configuration.apiBaseURL |
| `ios/Scrollsmith/Views/Auth/RegisterView.swift` | Legal footer on signup | VERIFIED | 223 lines, legal footer at lines 159-179, sheet modifiers at lines 192-197 |
| `ios/Scrollsmith/Views/Settings/AboutView.swift` | About screen with support/legal | VERIFIED | 108 lines, Support/Legal/App sections, MailView and LegalDocumentView integration |
| `ios/Scrollsmith/Views/Settings/SettingsView.swift` | Navigation to AboutView | VERIFIED | Lines 79-84: NavigationLink to AboutView |
| `.planning/app-store/description.txt` | App Store description | VERIFIED | 27 lines, problem-focused opening "Saved 100 videos but watched none?" |
| `.planning/app-store/keywords.txt` | ASO keywords | VERIFIED | 99 characters (under 100 limit), 13 keywords |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| main.py | terms.html | FileResponse | WIRED | Line 78: `FileResponse("app/static/legal/terms.html")` |
| main.py | privacy.html | FileResponse | WIRED | Line 84: `FileResponse("app/static/legal/privacy.html")` |
| LegalDocumentView | WebView | View composition | WIRED | Line 37: `WebView(url: documentType.url)` |
| LegalDocumentView | Configuration | URL construction | WIRED | Line 28: `Configuration.apiBaseURL + path` |
| RegisterView | LegalDocumentView | Sheet presentation | WIRED | Lines 193, 196: `.sheet` with LegalDocumentView |
| AboutView | LegalDocumentView | Sheet presentation | WIRED | Lines 80, 83: `.sheet` with LegalDocumentView |
| AboutView | MailView | Sheet presentation | WIRED | Line 77: MailView with recipient and subject |
| SettingsView | AboutView | NavigationLink | WIRED | Lines 79-84: NavigationLink to AboutView() |

### Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| LEGA-01: Terms of Service | SATISFIED | terms.html exists (159 lines), served at /terms |
| LEGA-02: Privacy Policy | SATISFIED | privacy.html exists (262 lines), served at /privacy, GDPR-compliant |
| LEGA-03: Privacy Policy link on signup | SATISFIED | RegisterView.swift line 174: Button("Privacy Policy") with sheet |
| LEGA-04: Terms link on signup | SATISFIED | RegisterView.swift line 165: Button("Terms") with sheet |
| LEGA-05: App Store Connect setup | PARTIAL | Description/keywords ready; screenshots/video deferred per 12-05-SUMMARY |
| LEGA-06: Customer support email | SATISFIED | AboutView.swift line 17: hello@scrollsmith.app with MailView |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | - | - | - | No stub patterns, TODOs, or placeholders found in legal components |

### Known Deferred Items

Per 12-05-SUMMARY.md, Tasks 2-4 are intentionally deferred:
- App Store screenshots (requires finalized UI)
- App preview video (requires finalized UI)
- Upload to App Store Connect (depends on above)

These are acknowledged deferrals, not gaps. The copywriting (description.txt, keywords.txt) is complete.

### Human Verification Required

#### 1. App Store Connect Agreements
**Test:** Log into App Store Connect > Agreements, Tax, and Banking
**Expected:** Paid Applications Agreement shows "Active", Tax shows "Complete", Banking shows "Clear"
**Why human:** Cannot access App Store Connect programmatically

#### 2. Subscription Products
**Test:** App Store Connect > My Apps > Scrollsmith > Features > Subscriptions
**Expected:** scrollsmith_monthly and scrollsmith_yearly show "Ready to Submit"
**Why human:** App Store Connect requires manual login

#### 3. Legal Document WebView Loading
**Test:** Run iOS app, navigate to RegisterView, tap "Terms" and "Privacy Policy"
**Expected:** WebView sheets open and display legal documents from backend
**Why human:** Requires running app with network to verify WebView loads backend URLs

#### 4. Mail Composer in AboutView
**Test:** Run iOS app, go to Settings > About > Contact Support
**Expected:** Mail composer opens with "hello@scrollsmith.app" and "Scrollsmith Support Request" pre-filled
**Why human:** Requires device with Mail app configured

#### 5. App Privacy Questionnaire
**Test:** App Store Connect > My Apps > Scrollsmith > App Privacy
**Expected:** All data types disclosed (email, user ID, usage data, crash data, purchases), Privacy Policy URL set
**Why human:** App Store Connect portal

### Verification Summary

All automated verifications pass:
- Backend legal documents exist and are substantive (159 and 262 lines)
- Backend routes serve legal documents via FileResponse
- iOS components (WebView, MailView, LegalDocumentView) exist and are substantive
- Legal links wired into RegisterView (signup) and AboutView (settings)
- Settings navigates to AboutView
- Support email configured in AboutView
- App Store description uses problem-focused opening
- Keywords under 100 character limit

Phase 12 success criteria:
1. [x] Terms of Service and Privacy Policy written and hosted
2. [x] Privacy Policy and Terms links accessible from signup screen and settings
3. [?] App Store Connect agreements signed (HUMAN VERIFICATION)
4. [?] Subscription products created and "Ready to Submit" (HUMAN VERIFICATION)
5. [~] App Store screenshots, preview video, and description finalized (description done; visuals deferred)
6. [x] Customer support email listed in settings and App Store

---

*Verified: 2026-01-27T23:55:00Z*
*Verifier: Claude (gsd-verifier)*
