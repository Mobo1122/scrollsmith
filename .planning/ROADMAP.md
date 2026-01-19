# Roadmap: Scrollsmith

**Created:** 2026-01-18
**Depth:** Comprehensive (8-12 phases)
**Mode:** YOLO (auto-approve)
**Parallelization:** Enabled

## Overview

**12 phases** | **85 v1 requirements** | **All requirements mapped** ✓

| # | Phase | Goal | Requirements | Plans |
|---|-------|------|--------------|-------|
| 1 | Foundation | Backend + iOS project scaffolding, database, deployment | 2 (INFR) | 4 plans |
| 2 | Authentication | Email/password + Apple Sign In with verification and password reset | 12 (AUTH) | 0/6 |
| 3 | Video Capture (iOS) | Camera roll, URL paste, Share Extension with permissions | 8 (CAPT) | 0/7 |
| 4 | Transcription | On-device (WhisperKit/Speech) + backend (Whisper/YouTube API) | 8 (CAPT) | 0/6 |
| 5 | AI Summarization | Claude integration for bullets, steps, cards, tags | 11 (SUMM) | 0/7 |
| 6 | Playbooks & Organization | CRUD Playbooks, video assignment, search, bulk operations | 12 (PLAY) | 0/6 |
| 7 | Summary Display | iOS UI for bullets, steps, cards with deep-linking | 8 (SUMM subset) | 0/5 |
| 8 | Subscription System | RevenueCat integration, free/Pro tiers, usage tracking | 13 (SUBS) | 0/8 |
| 9 | Habit Extraction | LLM habit suggestions from videos with Pro gating | 4 (HABT) | 0/5 |
| 10 | Habit Tracking | Notifications, completions, streaks, visualization | 13 (HABT) | 0/7 |
| 11 | Infrastructure & Polish | Analytics, crash reporting, webhook retry, error handling | 8 (INFR) | 0/6 |
| 12 | Legal & Launch Prep | Terms, Privacy Policy, App Store submission materials | 6 (LEGA) | 0/5 |

---

## Phase Details

### Phase 1: Foundation

**Goal:** Backend + iOS project scaffolding with database, deployment, and basic API connectivity

**Requirements:**
- INFR-01: Backend API deployed
- INFR-02: PostgreSQL database with schema

**Success Criteria:**
1. FastAPI backend deployed to Railway and accessible via HTTPS
2. PostgreSQL database created with migrations for users, videos, habits, playbooks tables
3. iOS project created with SwiftUI + SwiftData models matching backend schema
4. iOS app can ping backend health endpoint successfully
5. Alembic migrations run and track schema versions

**Dependencies:** None (foundation phase)

**Plans:** 4 plans

Plans:
- [ ] 01-01-PLAN.md — Backend Foundation (async SQLAlchemy, models, Alembic, health endpoint)
- [ ] 01-02-PLAN.md — iOS Foundation (SwiftUI + SwiftData models, networking layer)
- [ ] 01-03-PLAN.md — Railway Deployment (deploy backend, configure PostgreSQL)
- [ ] 01-04-PLAN.md — End-to-End Verification (test iOS -> Backend -> Database)

---

### Phase 2: Authentication

**Goal:** Complete auth system with email/password, Apple Sign In, email verification, and password reset

**Requirements:**
- AUTH-01: Email/password signup
- AUTH-02: Email verification after signup
- AUTH-03: Email verification link handling
- AUTH-04: Email/password login
- AUTH-05: Apple Sign In
- AUTH-06: Password reset request
- AUTH-07: Password reset via email link
- AUTH-08: Session persistence
- AUTH-09: Logout
- AUTH-10: Invalid credentials error
- AUTH-11: Network failure error
- AUTH-12: Loading spinners

**Success Criteria:**
1. User can sign up with email/password and receives verification email
2. User can verify email via link and then log in
3. User can request password reset and reset via email link
4. User can sign in with Apple ID (production and sandbox)
5. Sessions persist across app restarts using secure token storage
6. All error states (invalid credentials, network failures) display properly with retry options

**Dependencies:** Phase 1 (backend + iOS scaffolding)

**Plans:** 0/6
- [ ] Backend: JWT auth with access/refresh tokens
- [ ] Backend: Email service integration (SendGrid/AWS SES) for verification and password reset
- [ ] Backend: Apple Sign In token validation
- [ ] iOS: Email/password signup and login UI with error handling
- [ ] iOS: Apple Sign In integration with AuthenticationServices
- [ ] iOS: Token storage in Keychain and session management

---

### Phase 3: Video Capture (iOS)

**Goal:** iOS video capture from camera roll, URL paste, and Share Extension with proper permissions

**Requirements:**
- CAPT-01: Camera roll upload via PhotosPicker
- CAPT-02: Camera roll permission request
- CAPT-03: Non-video media error
- CAPT-04: Video preview before processing
- CAPT-05: URL paste
- CAPT-06: URL validation
- CAPT-07: Share Extension
- CAPT-11: Upload progress indicator

**Success Criteria:**
1. User can select video from camera roll with permission prompt
2. Non-video media shows clear error message
3. User sees video thumbnail preview before confirming upload
4. User can paste TikTok/IG/YouTube URL with format validation
5. Share Extension receives videos from other apps and saves to App Group
6. Upload progress shows percentage/spinner during file transfer
7. Main app processes pending uploads from Share Extension on launch

**Dependencies:** Phase 2 (auth required to associate videos with users)

**Plans:** 0/7
- [ ] iOS: PhotosPicker integration with permission handling
- [ ] iOS: Video preview UI with thumbnail generation
- [ ] iOS: URL input with regex validation for TikTok/IG/YouTube patterns
- [ ] iOS: Share Extension target with App Group configuration
- [ ] iOS: SwiftData shared container for pending uploads
- [ ] iOS: Upload progress UI with cancellation
- [ ] iOS: Main app processing of Share Extension queue

---

### Phase 4: Transcription

**Goal:** Transcribe videos via on-device (WhisperKit/Speech) for TikTok/IG, backend (Whisper API) for uploads, YouTube API for captions

**Requirements:**
- CAPT-08: On-device transcription (WhisperKit iOS 18+, Speech iOS 17)
- CAPT-09: Backend transcription (OpenAI Whisper API)
- CAPT-10: YouTube captions via API
- CAPT-12: Transcription progress indicator
- CAPT-13: Network error handling with retry
- CAPT-14: YouTube API rate limit fallback
- CAPT-15: Transcript-only storage
- CAPT-16: Delete uploaded video after transcription
- INFR-03: OpenAI Whisper API integration
- INFR-05: YouTube Data API integration

**Success Criteria:**
1. iOS 18+ devices transcribe TikTok/IG videos using WhisperKit on-device
2. iOS 17 devices fall back to Apple Speech Framework
3. Camera roll uploads send audio to backend, which transcribes via Whisper API and deletes audio file
4. YouTube URLs fetch captions via YouTube Data API when available
5. YouTube API quota errors fall back to on-device transcription with user notification
6. Transcription progress shows spinner/percentage
7. Only transcripts (not video files) are stored permanently in database

**Dependencies:** Phase 3 (video capture must exist first)

**Plans:** 0/6
- [ ] iOS: WhisperKit integration for iOS 18+ with model selection (tiny/base)
- [ ] iOS: Apple Speech Framework fallback for iOS 17
- [ ] iOS: Audio extraction from video using AVFoundation
- [ ] Backend: OpenAI Whisper API integration with audio file cleanup
- [ ] Backend: YouTube Data API integration for caption fetching
- [ ] Backend: Error handling for API rate limits with fallback logic

---

### Phase 5: AI Summarization

**Goal:** Claude API integration to generate bullets, step-by-step checklists, cards, and tags from transcripts

**Requirements:**
- SUMM-01: Bullet summary generation
- SUMM-02: Step-by-step checklist with timestamps (Pro)
- SUMM-03: Swipeable cards (Pro)
- SUMM-04: Auto-tag generation
- SUMM-09: Manual regeneration
- SUMM-10: Poor transcription quality handling
- SUMM-11: Manual summary editing
- INFR-04: Anthropic Claude API integration

**Success Criteria:**
1. Backend generates bullet summaries for all transcripts using Claude API
2. Backend generates step-by-step checklists with timestamps for Pro users
3. Backend generates swipeable card format for Pro users
4. Backend auto-generates 3-5 relevant tags per video
5. User can manually trigger summary regeneration if quality is poor
6. Backend detects low-confidence transcripts and warns user
7. User can edit summaries manually in-app
8. Summaries are cached—never regenerated unnecessarily

**Dependencies:** Phase 4 (transcripts must exist), Phase 2 (user tier determines formats)

**Plans:** 0/7
- [ ] Backend: Claude API integration with async calls
- [ ] Backend: Prompt engineering for bullet summaries
- [ ] Backend: Prompt engineering for step-by-step with timestamp extraction
- [ ] Backend: Prompt engineering for card format generation
- [ ] Backend: Tag generation prompt with keyword extraction
- [ ] Backend: Summary regeneration endpoint with quality checks
- [ ] iOS: Manual summary editing UI

---

### Phase 6: Playbooks & Organization

**Goal:** CRUD Playbooks, video assignment, search, deletion, and bulk operations

**Requirements:**
- PLAY-01: Create Playbook
- PLAY-02: Edit Playbook name
- PLAY-03: Delete Playbook
- PLAY-04: Assign video to Playbook
- PLAY-05: View videos in Playbook
- PLAY-06: View uncategorized videos
- PLAY-07: Edit tags
- PLAY-08: Full-text search
- PLAY-09: Delete video
- PLAY-10: Confirm deletion
- PLAY-11: Bulk delete
- PLAY-12: Bulk move

**Success Criteria:**
1. User can create, edit, and delete Playbooks
2. Deleting a Playbook moves videos to "Uncategorized" instead of deleting them
3. User can assign videos to Playbooks during capture or afterward
4. User can view all videos in a Playbook with sorting (newest first)
5. User can search across titles, transcripts, and tags with PostgreSQL full-text search
6. User can delete individual videos with confirmation dialog
7. User can bulk-select videos and delete or move to different Playbook

**Dependencies:** Phase 5 (videos with summaries/tags must exist)

**Plans:** 0/6
- [ ] Backend: Playbook CRUD API endpoints
- [ ] Backend: PostgreSQL full-text search indexes (GIN)
- [ ] Backend: Bulk operations API (delete, move)
- [ ] iOS: Playbook list and detail views
- [ ] iOS: Video grid with selection mode for bulk operations
- [ ] iOS: Search UI with real-time results

---

### Phase 7: Summary Display

**Goal:** iOS UI to display bullets, steps, cards with deep-linking to source videos

**Requirements:**
- SUMM-05: View bullet summary
- SUMM-06: View step-by-step (Pro)
- SUMM-07: View swipeable cards (Pro)
- SUMM-08: Deep-link to source

**Success Criteria:**
1. User can view bullet summary for any saved video
2. Pro users can view step-by-step checklist with tappable timestamps
3. Pro users can swipe through card-format summaries
4. User can tap "View Original" to deep-link to TikTok/IG/YouTube or open Photos app
5. Deep-links handle URL schemes correctly for each platform
6. Summary views are visually distinct and ADHD-friendly (clear hierarchy, readable)

**Dependencies:** Phase 5 (summaries must exist), Phase 8 (Pro tier check)

**Plans:** 0/5
- [ ] iOS: Bullet summary view with markdown rendering
- [ ] iOS: Step-by-step checklist view with timestamp jump buttons
- [ ] iOS: Swipeable card view with gesture handling
- [ ] iOS: Deep-linking to TikTok/IG/YouTube URLs and Photos app
- [ ] iOS: Pro tier UI gating for step-by-step and cards

---

### Phase 8: Subscription System

**Goal:** RevenueCat integration with free/Pro tiers, usage tracking, and IAP

**Requirements:**
- SUBS-01: Free tier 10 videos/month limit
- SUBS-02: Free tier bullets only
- SUBS-03: Free tier reset timing
- SUBS-04: Block 11th video
- SUBS-05: Pro unlimited videos
- SUBS-06: Pro all formats
- SUBS-07: Pro habits
- SUBS-08: Usage display
- SUBS-09: Upgrade prompt
- SUBS-10: Purchase IAP
- SUBS-11: Restore purchases
- SUBS-12: Backend subscription verification
- SUBS-13: Sandbox testing
- INFR-06: RevenueCat integration
- INFR-07: RevenueCat webhooks

**Success Criteria:**
1. Free users are limited to 10 videos per month (resets on 1st)
2. Free users see usage indicator (e.g., "7/10 videos this month")
3. 11th video triggers upgrade prompt instead of processing
4. Pro users unlock unlimited videos, all summary formats, and habit features
5. iOS app integrates RevenueCat SDK with StoreKit 2
6. User can purchase Pro subscription via App Store
7. User can restore previous purchases
8. Backend receives RevenueCat webhooks and updates subscription status
9. Backend verifies subscription status via RevenueCat API before unlocking Pro features
10. Sandbox IAP testing works with TestFlight

**Dependencies:** Phase 2 (user accounts), Phase 5 (summary formats to gate)

**Plans:** 0/8
- [ ] Backend: RevenueCat webhook handler with signature verification
- [ ] Backend: Subscription status API endpoint
- [ ] Backend: Monthly usage tracking table and reset logic
- [ ] iOS: RevenueCat SDK integration
- [ ] iOS: StoreKit 2 product configuration in App Store Connect
- [ ] iOS: Paywall UI with pricing display
- [ ] iOS: Restore purchases button
- [ ] iOS: Usage indicator in UI

---

### Phase 9: Habit Extraction

**Goal:** LLM extracts 1-3 habits from videos with Pro tier gating

**Requirements:**
- HABT-01: "Make action points" button
- HABT-02: LLM suggests 1-3 habits
- HABT-03: User selects habits to create
- HABT-04: Set frequency

**Success Criteria:**
1. Pro users see "Make action points" button on summarized videos
2. Claude API generates 1-3 concrete, recurring habit suggestions from video transcript
3. User can select which habits to create (all, some, or none)
4. User sets frequency per habit (daily, 3×weekly, weekly)
5. Free users see upgrade prompt when tapping "Make action points"

**Dependencies:** Phase 8 (Pro tier check), Phase 5 (summaries exist)

**Plans:** 0/5
- [ ] Backend: Claude API prompt for habit extraction
- [ ] Backend: Habit creation API endpoint
- [ ] iOS: "Make action points" button with Pro gate
- [ ] iOS: Habit suggestion list UI with selection
- [ ] iOS: Frequency picker (daily/3×weekly/weekly)

---

### Phase 10: Habit Tracking

**Goal:** Push notifications, completions, streaks, visualization, and editing

**Requirements:**
- HABT-05: Set reminder time
- HABT-06: Request notification permission
- HABT-07: In-app fallback if denied
- HABT-08: Push notification at scheduled time
- HABT-09: Mark complete from notification
- HABT-10: Mark complete in-app
- HABT-11: Current streak tracking
- HABT-12: Longest streak tracking
- HABT-13: 1-day streak forgiveness
- HABT-14: Habit list with streak visualization
- HABT-15: View source video from habit
- HABT-16: Edit habit details
- HABT-17: Delete habit

**Success Criteria:**
1. User sets reminder time for each habit
2. App requests notification permission with clear value proposition ("Never forget your habits")
3. If notifications denied, in-app reminder UI shows pending habits
4. User receives push notification at scheduled time with quick completion action
5. User can mark habit complete from notification or in-app
6. Streaks are tracked with 1-day forgiveness (missing one day doesn't reset streak)
7. Habit list shows current streak and longest streak with calendar/chart visualization
8. User can tap habit to view source video
9. User can edit habit title, frequency, or reminder time
10. User can delete habit with confirmation

**Dependencies:** Phase 9 (habits must be created first)

**Plans:** 0/7
- [ ] iOS: UNUserNotificationCenter permission request
- [ ] iOS: Local notification scheduling based on frequency
- [ ] iOS: Notification action handler for quick completion
- [ ] iOS: In-app habit list with streak display (calendar or chart)
- [ ] Backend: Habit completion logging with timezone handling
- [ ] Backend: Streak calculation with 1-day forgiveness logic
- [ ] iOS: Habit editing UI

---

### Phase 11: Infrastructure & Polish

**Goal:** Analytics, crash reporting, webhook retry, and production-grade error handling

**Requirements:**
- INFR-08: Webhook retry logic
- INFR-09: Crash reporting
- INFR-10: Analytics tracking

**Success Criteria:**
1. Backend retries failed RevenueCat webhooks with exponential backoff
2. iOS app includes crash reporting (Sentry or Firebase Crashlytics)
3. Analytics track key metrics: video views, habit completions, free→Pro conversions, retention
4. All API errors log to backend with context (user ID, request, stack trace)
5. iOS shows user-friendly error messages for all failure scenarios
6. Backend handles LLM API errors gracefully (retry, fallback, timeout)

**Dependencies:** Phase 10 (all features exist to track)

**Plans:** 0/6
- [ ] Backend: Webhook retry queue with exponential backoff
- [ ] Backend: Sentry integration for error tracking
- [ ] iOS: Firebase Analytics or Mixpanel integration
- [ ] iOS: Event tracking for conversions and retention
- [ ] Backend: LLM error handling (timeout, retry, fallback)
- [ ] iOS: Comprehensive error state UI

---

### Phase 12: Legal & Launch Prep

**Goal:** Terms of Service, Privacy Policy, App Store submission materials

**Requirements:**
- LEGA-01: Terms of Service
- LEGA-02: Privacy Policy
- LEGA-03: Privacy Policy link on signup
- LEGA-04: Terms link on signup
- LEGA-05: App Store Connect setup
- LEGA-06: Customer support email

**Success Criteria:**
1. Terms of Service and Privacy Policy written and hosted
2. Privacy Policy and Terms links accessible from signup screen and settings
3. App Store Connect agreements signed
4. Subscription products created and "Ready to Submit"
5. App Store screenshots, preview video, and description finalized
6. Customer support email listed in settings and App Store

**Dependencies:** Phase 11 (app must be feature-complete)

**Plans:** 0/5
- [ ] Write Terms of Service and Privacy Policy
- [ ] Host Terms and Privacy Policy (static site or backend)
- [ ] iOS: Add Terms and Privacy links to signup and settings
- [ ] App Store Connect: Create subscription products and agreements
- [ ] Create App Store marketing materials (screenshots, video, description)

---

## Traceability Updates

All 85 v1 requirements are now mapped to phases 1-12.

---

*Roadmap created: 2026-01-18*
*Last updated: 2026-01-19 after Phase 1 planning*
