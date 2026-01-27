---
phase: 12-legal-launch-prep
plan: 01
subsystem: legal
tags: [legal, gdpr, terms-of-service, privacy-policy, fastapi]
dependency-graph:
  requires: []
  provides: [legal-documents, terms-endpoint, privacy-endpoint]
  affects: [12-02, 12-03]
tech-stack:
  added: []
  patterns: [static-file-serving, FileResponse]
key-files:
  created:
    - backend/app/static/legal/terms.html
    - backend/app/static/legal/privacy.html
  modified:
    - backend/app/main.py
decisions:
  - "Root-level endpoints (/terms, /privacy) for public-facing legal pages"
  - "GDPR-compliant AI/LLM disclosure with specific third-party processor table"
  - "England & Wales jurisdiction per CONTEXT.md requirements"
metrics:
  duration: 2min
  completed: 2026-01-27
---

# Phase 12 Plan 01: Legal Document Hosting Summary

**One-liner:** Terms of Service and Privacy Policy HTML endpoints with GDPR-compliant AI/LLM processing disclosure and England & Wales jurisdiction.

## What Was Built

Created static HTML legal documents and FastAPI endpoints for iOS WebView display:

1. **Terms of Service** (`/terms`):
   - Standard legal language for subscription apps
   - Apple auto-renewal and cancellation terms
   - User-generated content licence for AI processing
   - Limitation of liability and disclaimer of warranties
   - England & Wales jurisdiction clause

2. **Privacy Policy** (`/privacy`):
   - GDPR-compliant structure with all required sections
   - Clear AI/LLM processing disclosure table:
     - OpenAI Whisper API for transcription
     - Anthropic Claude for summarization
   - Explicit statement: "Your data is not used to train AI models"
   - Third-party processor table (OpenAI, Anthropic, RevenueCat, Sentry, Mixpanel, Railway)
   - Data subject rights (access, deletion, portability, objection)
   - ICO complaint process reference
   - Contact: hello@scrollsmith.app

3. **FastAPI Routes**:
   - `GET /terms` - serves terms.html via FileResponse
   - `GET /privacy` - serves privacy.html via FileResponse
   - Public endpoints (no authentication required)

## Technical Implementation

```
backend/app/static/legal/
  terms.html   (9.1 KB) - Terms of Service
  privacy.html (11.5 KB) - Privacy Policy

backend/app/main.py
  + FileResponse import
  + GET /terms endpoint
  + GET /privacy endpoint
```

## Key Files

| File | Purpose | Key Content |
|------|---------|-------------|
| `backend/app/static/legal/terms.html` | Terms of Service | Subscription terms, liability limits, E&W jurisdiction |
| `backend/app/static/legal/privacy.html` | Privacy Policy | GDPR structure, AI disclosure, data rights |
| `backend/app/main.py` | Legal routes | /terms and /privacy endpoints |

## Commits

| Hash | Message | Files |
|------|---------|-------|
| e8abd86 | feat(12-01): create Terms of Service and Privacy Policy HTML files | terms.html, privacy.html |
| cf1e965 | feat(12-01): add /terms and /privacy FastAPI endpoints | main.py |

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Root-level endpoints | Legal pages are public-facing, not API resources - /terms not /api/v1/terms |
| Inline CSS styling | No external dependencies, works offline, supports iOS WebView |
| Dark mode support | Matches iOS system appearance preference |
| AI processing table format | Clear, scannable disclosure of what data goes where |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

All must_haves verified:
- [x] GET /terms returns Terms of Service HTML page
- [x] GET /privacy returns Privacy Policy HTML page
- [x] Legal documents include GDPR-compliant AI/LLM processing disclosure
- [x] Legal documents specify England & Wales jurisdiction
- [x] Mobile-responsive (viewport meta tag present)
- [x] FileResponse pattern matches key_links requirement

## Production URLs

After Railway deployment:
- https://backend-production-d73a.up.railway.app/terms
- https://backend-production-d73a.up.railway.app/privacy

## Next Phase Readiness

Plan 12-02 (Apple metadata) can proceed - no blockers.

iOS can now display legal documents in WebView sheets using these endpoints.
