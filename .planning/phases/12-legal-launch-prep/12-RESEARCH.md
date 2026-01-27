# Phase 12: Legal & Launch Prep - Research

**Researched:** 2026-01-27
**Domain:** Legal compliance, FastAPI HTML serving, SwiftUI WebView, App Store submission
**Confidence:** HIGH

## Summary

Phase 12 focuses on legal compliance and App Store launch preparation. The implementation involves four distinct domains: (1) creating GDPR-compliant legal documents for a UK-based subscription app with AI processing, (2) serving static HTML pages via FastAPI, (3) displaying legal documents in SwiftUI using WKWebView sheets, and (4) preparing App Store marketing assets and subscription products for submission.

Key findings indicate that Apple's 2026 requirements have evolved significantly: app preview videos must now be actual screen recordings (no animated promotional content allowed), screenshots with headline captions are indexed for search, and privacy nutrition labels require detailed third-party SDK disclosure. For GDPR compliance with AI/LLM processing, the August 2026 EU AI Act deadline creates dual compliance obligations requiring transparency about automated processing and data subject rights mechanisms.

The technical implementation is straightforward: FastAPI's `StaticFiles` mount for legal documents, `UIViewControllerRepresentable` wrapper for `MFMailComposeViewController` with pre-filled subjects, and standard App Store Connect subscription setup requiring "Ready to Submit" status before TestFlight testing.

**Primary recommendation:** Follow Apple's screen recording requirement strictly for app previews (no animated promos), use established GDPR privacy policy generators for compliance baseline, and complete App Store Connect subscription configuration early as product propagation takes several hours.

## Standard Stack

The established tools for legal documents and App Store submission:

### Core

| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| FastAPI StaticFiles | FastAPI 0.115+ | Static HTML serving | Built-in, zero dependencies, official FastAPI pattern |
| MFMailComposeViewController | iOS 18+ SDK | Email composition | Native iOS mail integration, system-level UX |
| App Store Connect | 2026 | Subscription products | Only platform for iOS app distribution |
| Privacy policy generators | 2026 compliant | Legal templates | GDPR/UK-specific, regularly updated for law changes |

### Supporting

| Library/Tool | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| Jinja2 | 3.1+ | Template rendering | If legal docs need dynamic data (user email, dates) |
| WKWebView | iOS 18+ | In-app browser | Display legal HTML without leaving app |
| UIViewRepresentable | SwiftUI | UIKit bridge | Wrap MFMailComposeViewController for SwiftUI |
| RevenueCat docs | Latest | Subscription guidance | Reference for App Store Connect setup patterns |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static HTML files | Markdown + conversion | HTML gives precise control over formatting and layout |
| In-app WebView | External Safari | WebView keeps users in-app, better UX for legal docs during signup |
| Screen recording | Animated promo | REJECTED by Apple - only screen recordings allowed per 2026 policy |
| Manual privacy policy | Legal consultation | Generators provide baseline, consultation needed for AI/LLM disclosures |

**Installation:**
```bash
# FastAPI (already in project)
pip install fastapi

# iOS - native frameworks, no installation needed
# - MessageUI (MFMailComposeViewController)
# - WebKit (WKWebView)
```

## Architecture Patterns

### Recommended Project Structure

```
backend/
├── app/
│   ├── static/
│   │   ├── legal/
│   │   │   ├── terms.html
│   │   │   └── privacy.html
│   └── main.py          # Mount StaticFiles here

ios/
├── Scrollsmith/
│   ├── Views/
│   │   ├── Settings/
│   │   │   ├── AboutView.swift        # New - version, support, legal links
│   │   │   └── SettingsView.swift     # Add About link
│   │   └── Auth/
│   │       └── RegisterView.swift     # Add legal footer
│   └── Components/
│       ├── WebView.swift              # UIViewRepresentable wrapper
│       └── MailComposer.swift         # MFMailComposeViewController wrapper

.planning/
└── app-store/
    ├── screenshots/                    # 6.9" iPhone base device
    ├── preview-video/                  # 15-30s screen recording
    ├── description.txt                 # Problem-focused copy
    └── keywords.txt                    # ASO metadata
```

### Pattern 1: FastAPI Static HTML Serving

**What:** Mount a StaticFiles instance to serve legal documents at `/terms` and `/privacy` endpoints.

**When to use:** Serving static HTML pages that don't require dynamic rendering or authentication.

**Example:**
```python
# Source: https://fastapi.tiangolo.com/tutorial/static-files/
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Mount static files for legal documents
app.mount("/static", StaticFiles(directory="static"), name="static")

# Or serve directly at root-level paths with custom routes
from fastapi.responses import FileResponse

@app.get("/terms")
async def terms_of_service():
    return FileResponse("static/legal/terms.html")

@app.get("/privacy")
async def privacy_policy():
    return FileResponse("static/legal/privacy.html")
```

### Pattern 2: SwiftUI WebView for Legal Documents

**What:** UIViewRepresentable wrapper around WKWebView to display HTML content in sheets.

**When to use:** Displaying legal documents, help content, or web-based content within the app.

**Example:**
```swift
// Source: https://sarunw.com/posts/swiftui-webview/
// and https://medium.com/@diegodossantos1/in-app-browser-with-wkwebview-and-swiftui-2c2a3dba9b57
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// Usage in a sheet
struct LegalDocumentView: View {
    let documentURL: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            WebView(url: documentURL)
                .navigationTitle("Terms of Service")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
```

### Pattern 3: Mail Compose with Pre-filled Subject

**What:** UIViewControllerRepresentable wrapper around MFMailComposeViewController for support emails.

**When to use:** Providing customer support contact with pre-filled email details.

**Example:**
```swift
// Source: https://codewithchris.com/sending-email-in-swiftui/
// and https://serialcoder.dev/text-tutorials/swiftui/composing-emails-in-swiftui-using-a-view-modifier/
import SwiftUI
import MessageUI

struct MailView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.mailComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailView

        init(_ parent: MailView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                  didFinishWith result: MFMailComposeResult,
                                  error: Error?) {
            parent.dismiss()
        }
    }
}

// Usage
.sheet(isPresented: $showingMailComposer) {
    MailView(
        recipient: "hello@scrollsmith.app",
        subject: "Scrollsmith Support Request"
    )
}
```

### Pattern 4: App Store Screenshot Structure

**What:** Device frames with benefit-focused headline captions above each screenshot.

**When to use:** Creating App Store marketing assets for conversion optimization.

**Best practices:**
```
Screenshot 1 (Hero):
- Headline: "Finally watch your saved videos" (3-7 words)
- Visual: Main app interface showing video library
- Emotion: Relief ("finally"), urgency

Screenshot 2 (Core benefit):
- Headline: "Turn content into action instantly"
- Visual: Summary/playbook interface
- Action verb: "Turn", benefit: "action"

Screenshot 3 (Social proof/differentiator):
- Headline: "Your videos, your insights"
- Visual: Unique feature (habit tracking, search)
- Personalization: "Your"

Screenshots 4-5: Secondary features
- Keep headlines keyword-rich (App Store indexes caption text)
- Focus on benefits over features
```

### Anti-Patterns to Avoid

- **Animated promotional videos for app previews:** Apple requires actual screen recordings only. Promotional videos with motion graphics will be rejected. (Source: https://developer.apple.com/app-store/app-previews/)

- **Opening legal links in external Safari:** Breaks signup flow, reduces conversion. Use in-app WebView sheets instead.

- **Generic privacy policy without AI/LLM disclosure:** GDPR requires transparency about automated processing. Failure to disclose LLM usage risks non-compliance.

- **Submitting without "Ready to Submit" status:** Products won't work in TestFlight. Complete all localization, tax/banking info first.

- **Feature-focused screenshot captions:** "Video transcription" vs "Never forget what you learned" - benefits convert better.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Privacy Policy content | Custom legal writing | GDPR policy generators + legal review | Generators cover 90% of standard clauses, lawyers focus on AI-specific sections |
| Terms of Service clauses | Write from scratch | Template generators (GetTerms, TermsFeed) | Standard subscription terms well-established, templates updated for law changes |
| App Store screenshot design | Manual Photoshop per size | Screenshot design tools (ScreenshotWhale) | Automatic sizing for all device classes, templates for captions |
| Email validation in forms | Regex patterns | iOS native validation | System handles edge cases, consistent UX |
| In-app browser navigation | Custom toolbar | Native WKWebView navigation | Back/forward/reload patterns expected by users |

**Key insight:** Legal and marketing domains have mature tooling. Custom solutions introduce compliance risk (legal) and conversion losses (marketing). Use established tools as baseline, customize minimally.

## Common Pitfalls

### Pitfall 1: App Preview Video Content Violation

**What goes wrong:** Submitting animated promotional videos instead of screen recordings results in App Store rejection.

**Why it happens:** Context document mentions "animated promo with motion graphics" but Apple's 2026 policy strictly requires actual on-device screen recordings.

**How to avoid:**
- Record actual app screens using iOS Simulator or device screen recording
- Duration: 15-30 seconds
- Format: H.264 (.mov, .m4v, .mp4) or ProRes 422 HQ (.mov)
- No hands, no over-the-shoulder shots, no simulated content
- App content only - what users actually see when using the app

**Warning signs:** If your video includes anything not visible within the app itself, it will be rejected.

**CRITICAL:** This contradicts the prior decision to create an "animated promo with motion graphics". The planner MUST flag this conflict and recommend actual screen recording instead.

### Pitfall 2: Incomplete Subscription Product Configuration

**What goes wrong:** Products not showing in TestFlight or app stuck in "Waiting for Review" due to missing subscription setup.

**Why it happens:** "Ready to Submit" status requires completing multiple steps across different App Store Connect sections.

**How to avoid:**
1. Complete paid applications agreement
2. Add tax information (all jurisdictions)
3. Add banking information (status: "Clear")
4. Create subscription group
5. Configure product with reference name, product ID, duration, pricing
6. Complete all localization fields
7. Add subscription screenshot
8. Verify status shows "Ready to Submit" not "Missing Metadata"

**Warning signs:**
- Products don't appear in RevenueCat dashboard after 2+ hours
- TestFlight builds can't fetch product list
- App Store Connect shows yellow warning badges

**Timeline:** Products take several hours to propagate through Apple's systems. Create products early in the phase.

### Pitfall 3: GDPR AI/LLM Disclosure Gap

**What goes wrong:** Privacy policy omits AI processing details, creating compliance risk under GDPR and upcoming EU AI Act.

**Why it happens:** Standard privacy policy templates don't cover LLM-specific requirements (training data, automated decisions, data subject rights over models).

**How to avoid:**
- Explicitly state use of LLMs for video transcription and summarization
- Disclose legal basis (likely legitimate interests - requires balancing assessment)
- Explain data subject rights: how to request deletion from training data
- Note: Deletion may require model retraining (up to 3 months)
- Include DPIA for high-risk processing
- Clarify whether outputs may "memorize" personal data

**Warning signs:**
- Privacy policy only mentions "data processing" without specifying AI
- No section on automated decision-making
- No explanation of how users can exercise rights over AI-processed data

**EU AI Act deadline:** August 2, 2026 - high-risk AI systems require compliance

### Pitfall 4: Privacy Nutrition Label Third-Party SDK Omissions

**What goes wrong:** Incomplete App Privacy Details in App Store Connect due to unlisted third-party SDK data collection.

**Why it happens:** Developers focus on first-party data collection, forgetting that analytics and crash reporting SDKs (Sentry, RevenueCat, etc.) also collect and transmit data.

**How to avoid:**
- Audit all third-party SDKs in project
- Check each SDK's privacy manifest or documentation
- Declare data types: identifiers, usage data, diagnostics
- Mark whether data is linked to user identity
- Specify purpose: analytics, app functionality, developer advertising

**Warning signs:**
- App Review rejection citing undisclosed data collection
- SDK documentation mentions data transmission but not in privacy label

**Data definition:** "Collect" = transmitting data off-device for longer than real-time request servicing

### Pitfall 5: Screenshot Size and Base Device Mismatch

**What goes wrong:** Screenshots not displaying on all device sizes or appearing stretched/cropped.

**Why it happens:** 2026 requires 6.9" iPhone as base device, not previous 6.5" standard.

**How to avoid:**
- Create screenshots at 1260 × 2736 px (portrait) or 2736 × 1260 px (landscape)
- Base devices: iPhone 17 Pro Max, iPhone 16 Pro Max, iPhone 16 Plus
- Apple auto-scales to smaller devices
- Formats: .jpeg, .jpg, .png
- Upload 1-10 screenshots (recommend 5 for optimal conversion)

**Warning signs:**
- App Store Connect warnings about screenshot resolution
- Previews look pixelated on larger devices

### Pitfall 6: Legal Links Breaking Signup Flow

**What goes wrong:** Users tap Privacy Policy during signup, navigate to Safari, lose context, abandon signup.

**Why it happens:** Using `Link` with external URL instead of in-app sheet presentation.

**How to avoid:**
- Use `.sheet()` modifier with WebView for legal documents
- Keep users in-app during signup flow
- Add "Done" button in navigation bar for easy dismissal
- Legal links should be tappable inline text, not buttons

**Warning signs:**
- Analytics show high drop-off rates when legal links are tapped
- User complaints about losing signup progress

## Code Examples

Verified patterns from official sources:

### FastAPI Legal Document Routes

```python
# Source: https://fastapi.tiangolo.com/tutorial/static-files/
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI()

# Create static directory structure
STATIC_DIR = "app/static/legal"
os.makedirs(STATIC_DIR, exist_ok=True)

# Serve individual legal documents
@app.get("/terms")
async def terms_of_service():
    """Serve Terms of Service HTML page."""
    return FileResponse(f"{STATIC_DIR}/terms.html", media_type="text/html")

@app.get("/privacy")
async def privacy_policy():
    """Serve Privacy Policy HTML page."""
    return FileResponse(f"{STATIC_DIR}/privacy.html", media_type="text/html")

# Alternative: Mount entire static directory
# app.mount("/legal", StaticFiles(directory=STATIC_DIR), name="legal")
# Then access via /legal/terms.html and /legal/privacy.html
```

### SwiftUI Legal Document Sheet with WebView

```swift
// Source: https://sarunw.com/posts/swiftui-webview/
import SwiftUI
import WebKit

// MARK: - WebView UIViewRepresentable
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// MARK: - Legal Document View
struct LegalDocumentView: View {
    enum DocumentType {
        case terms, privacy

        var title: String {
            switch self {
            case .terms: return "Terms of Service"
            case .privacy: return "Privacy Policy"
            }
        }

        var url: URL {
            let baseURL = "https://api.scrollsmith.app" // Or from Configuration
            switch self {
            case .terms: return URL(string: "\(baseURL)/terms")!
            case .privacy: return URL(string: "\(baseURL)/privacy")!
            }
        }
    }

    let documentType: DocumentType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            WebView(url: documentType.url)
                .navigationTitle(documentType.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Usage in RegisterView
struct RegisterView: View {
    @State private var showingTerms = false
    @State private var showingPrivacy = false

    var body: some View {
        VStack {
            // ... signup form fields ...

            // Legal footer
            Text("By signing up, you agree to our ")
                + Text("Terms")
                    .foregroundColor(.blue)
                    .underline()
                + Text(" and ")
                + Text("Privacy Policy")
                    .foregroundColor(.blue)
                    .underline()
        }
        .font(.footnote)
        .onTapGesture { location in
            // Detect which link was tapped
            // For simplicity, using separate buttons:
        }

        HStack(spacing: 4) {
            Text("By signing up, you agree to our")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button("Terms") {
                showingTerms = true
            }
            .font(.footnote)

            Text("and")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button("Privacy Policy") {
                showingPrivacy = true
            }
            .font(.footnote)
        }
        .sheet(isPresented: $showingTerms) {
            LegalDocumentView(documentType: .terms)
        }
        .sheet(isPresented: $showingPrivacy) {
            LegalDocumentView(documentType: .privacy)
        }
    }
}
```

### Support Email with MFMailComposeViewController

```swift
// Source: https://codewithchris.com/sending-email-in-swiftui/
import SwiftUI
import MessageUI

// MARK: - Mail Composer View
struct MailView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.mailComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailView

        init(_ parent: MailView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            parent.dismiss()
        }
    }
}

// MARK: - About/Settings View Usage
struct AboutView: View {
    @State private var showingMailComposer = false
    @State private var canSendMail = MFMailComposeViewController.canSendMail()

    var body: some View {
        List {
            Section("Support") {
                Button {
                    if canSendMail {
                        showingMailComposer = true
                    } else {
                        // Fallback: Open mailto URL
                        let email = "hello@scrollsmith.app"
                        let subject = "Scrollsmith Support Request"
                        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                            UIApplication.shared.open(url)
                        }
                    }
                } label: {
                    HStack {
                        Text("Contact Support")
                        Spacer()
                        Text("hello@scrollsmith.app")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Legal") {
                NavigationLink("Terms of Service") {
                    LegalDocumentView(documentType: .terms)
                }
                NavigationLink("Privacy Policy") {
                    LegalDocumentView(documentType: .privacy)
                }
            }

            Section("App Info") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("About")
        .sheet(isPresented: $showingMailComposer) {
            MailView(
                recipient: "hello@scrollsmith.app",
                subject: "Scrollsmith Support Request"
            )
        }
    }
}
```

### App Store Connect Subscription Product Setup

```swift
// This is configuration, not code - documenting the process

/*
Source: https://www.revenuecat.com/docs/getting-started/entitlements/ios-products

1. Prerequisites (App Store Connect):
   - Accept Paid Applications Agreement
   - Add Tax Information (all jurisdictions)
   - Add Banking Information (must show "Clear" status)

2. Create Subscription Group:
   - App Store Connect → My Apps → [Your App] → Features → Subscriptions
   - Click "+" to create Subscription Group
   - Name: "Scrollsmith Pro" (reference name, not user-facing)

3. Create Subscription Product:
   - Within Subscription Group, click "+" to add product
   - Reference Name: "Scrollsmith Pro Monthly" (internal only)
   - Product ID: "scrollsmith_pro_monthly" (permanent, can't reuse)
   - Duration: 1 month (dropdown)
   - Subscription Prices: Click "+" to set price
     - Select base currency and price tier
     - Apple auto-converts to all regions

4. Localization:
   - Display Name: "Scrollsmith Pro" (user-facing)
   - Description: Brief explanation of benefits

5. Review Information:
   - Screenshot: Upload screenshot showing subscription benefits

6. Verify Status:
   - Must show "Ready to Submit" before TestFlight testing
   - Takes 2-6 hours to propagate to RevenueCat/StoreKit

7. RevenueCat Integration:
   - Project Settings → Apps → Select App
   - Add product IDs created in App Store Connect
   - Create Entitlement (e.g., "pro")
   - Create Offering and attach products
*/
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Animated app preview promos | Screen recordings only | 2025-2026 | Promotional videos rejected; must show actual app UI |
| 6.5" iPhone screenshots | 6.9" iPhone base device | 2026 | New base size: 1260 × 2736 px for latest devices |
| Keyword-stuffed descriptions | Natural language, intent-based | 2025-2026 | App Store search understands context, not just keywords |
| Privacy policy = generic template | AI/LLM-specific disclosures | 2024-2026 | GDPR + EU AI Act require transparency about automated processing |
| Privacy labels: first-party only | Include all third-party SDKs | 2020-ongoing | Must disclose analytics, crash reporting, ad network data |
| Manual screenshot sizing | Auto-scaling from base device | 2026 | Submit 6.9" size, Apple scales down for older devices |

**Deprecated/outdated:**
- **Animated promotional videos for app previews**: Strictly prohibited. Apple requires actual on-device screen recordings showing real app content.
- **6.5" as base screenshot size**: Superseded by 6.9" displays on iPhone 16/17 Pro Max and Plus models.
- **Privacy policies without AI disclosure**: Non-compliant under GDPR for apps using LLMs. Must explicitly state automated processing.

## Open Questions

Things that couldn't be fully resolved:

1. **App Preview Video Content Conflict**
   - What we know: Prior context specifies "animated promo with motion graphics" but Apple's 2026 policy strictly requires actual screen recordings only
   - What's unclear: Whether user is aware of this Apple restriction
   - Recommendation: **Planner must flag this conflict immediately**. Recommend creating actual screen recording instead of animated promotional video. If user insists on animated content, it must be limited to screenshots with motion graphics overlays, not the app preview video.

2. **Privacy Policy AI/LLM Legal Basis**
   - What we know: GDPR requires legal basis for processing (likely "legitimate interests" for AI summarization)
   - What's unclear: Whether legitimate interests assessment has been completed, or if consent is preferred
   - Recommendation: Use privacy policy generator for baseline, add AI section under "legitimate interests" with user benefit justification (improve content consumption). Flag for legal review if budget allows.

3. **Data Subject Rights Implementation Timeline**
   - What we know: GDPR requires mechanisms for deletion, including from AI models (may require retraining)
   - What's unclear: Whether v1 launch needs full implementation or if process documentation suffices
   - Recommendation: For v1, include privacy policy disclosure that deletion requests are handled within 30 days, with AI model retraining occurring in quarterly batches. Implement request handling process, defer actual retraining capability to post-launch.

4. **Screenshot Feature Order Priority**
   - What we know: First 3 screenshots are critical (90% don't scroll past), should show highest-value features
   - What's unclear: Which Scrollsmith features convert best (video library, summaries, playbooks, habits)
   - Recommendation: Default order: (1) Summary cards (core value prop), (2) Video library with search, (3) Playbook/habits (differentiation), (4) Upload flow, (5) Settings/Pro. Plan for A/B testing post-launch using Apple's Product Page Optimization.

5. **Privacy Nutrition Label: RevenueCat Data Collection**
   - What we know: RevenueCat collects subscription and user data, must be disclosed in privacy label
   - What's unclear: Exact data types RevenueCat transmits (identifiers, purchase history, diagnostics)
   - Recommendation: Review RevenueCat's privacy manifest documentation before completing App Privacy Details questionnaire. Likely categories: Identifiers (Customer ID), Purchases (subscription history), Diagnostics (SDK errors).

## Sources

### Primary (HIGH confidence)

- [FastAPI Static Files Documentation](https://fastapi.tiangolo.com/tutorial/static-files/) - Official FastAPI static file serving patterns
- [Apple App Preview Specifications](https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications/) - Official technical requirements for app preview videos
- [Apple Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/) - Official screenshot size requirements for 2026
- [Apple In-App Purchase Statuses](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-statuses/) - "Ready to Submit" requirements
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) - Privacy nutrition label requirements
- [SwiftUI WebView - Sarunw](https://sarunw.com/posts/swiftui-webview/) - Verified SwiftUI WebView implementation pattern
- [Sending Email in SwiftUI - CodeWithChris](https://codewithchris.com/sending-email-in-swiftui/) - MFMailComposeViewController wrapper pattern
- [RevenueCat iOS Product Setup](https://www.revenuecat.com/docs/getting-started/entitlements/ios-products) - Subscription product configuration guide
- [RevenueCat App Store Connect Setup](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/app-store-connect-setup-guide) - Complete App Store Connect configuration

### Secondary (MEDIUM confidence)

- [TermsFeed - iOS Privacy Policy Requirements](https://www.termsfeed.com/blog/ios-apps-privacy-policy/) - Verified iOS legal requirements
- [GDPR Compliance 2026 - SecurePrivacy](https://secureprivacy.ai/blog/gdpr-compliance-2026) - AI/LLM data processing requirements
- [App Store Screenshot Best Practices - SplitMetrics](https://splitmetrics.com/blog/app-store-screenshots-aso-guide/) - Conversion optimization patterns
- [ASO Trends 2026 - Promodo](https://www.promodo.com/blog/aso-trends) - Natural language search evolution
- [GDPR LLM Lifecycle - Private AI](https://www.private-ai.com/en/2024/04/02/gdpr-llm-lifecycle/) - Data subject rights for AI models
- [Apple Privacy Measures - Medium](https://medium.com/axel-springer-tech/apple-privacy-measures-gdpr-privacy-nutrition-labels-app-tracking-transparency-and-privacy-912a7dabc85e) - Privacy nutrition label third-party SDK requirements

### Tertiary (LOW confidence - flagged for validation)

- Various privacy policy generator websites (GetTerms, iubenda) - Used for understanding template structure, not legal advice
- Medium articles on app preview best practices - General guidance, verify against Apple docs
- Blog posts on ASO trends - Industry observations, not official Apple policy

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - FastAPI StaticFiles and iOS native frameworks (MessageUI, WebKit) are official, well-documented solutions
- Architecture: **HIGH** - Patterns verified from official Apple and FastAPI documentation with working code examples
- Pitfalls: **HIGH** - App preview screen recording requirement, subscription "Ready to Submit" status, and privacy nutrition label third-party SDK disclosure are documented Apple requirements
- Legal compliance: **MEDIUM** - GDPR/UK requirements verified from official sources, but AI/LLM specific disclosures are evolving area (EU AI Act deadline August 2026)
- Marketing assets: **MEDIUM** - Screenshot best practices verified from multiple ASO sources, but conversion data is industry-specific

**Critical conflict identified:**
- Prior decision specifies "animated promo with motion graphics" for preview video
- Apple's 2026 policy REQUIRES actual screen recordings only
- **Planner must flag this and recommend screen recording instead**

**Research date:** 2026-01-27
**Valid until:** 2026-04-30 (90 days - legal requirements stable, but EU AI Act August deadline approaching)
