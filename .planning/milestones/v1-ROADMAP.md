# Milestone v1: MVP

**Status:** ✅ SHIPPED 2026-01-28
**Phases:** 1-12
**Total Plans:** 70

## Overview

Scrollsmith v1 MVP - a complete iOS app with FastAPI backend that transforms saved short-form videos into organized Playbooks with AI-generated summaries and trackable habits. Targets ADHD users who save great video content but never act on it.

## Phases

### Phase 1: Foundation

**Goal**: Backend + iOS project scaffolding with database, deployment, and basic API connectivity
**Depends on**: None (foundation phase)
**Plans**: 4 plans

Plans:
- [x] 01-01: Backend Foundation (async SQLAlchemy, models, Alembic, health endpoint)
- [x] 01-02: iOS Foundation (SwiftUI + SwiftData models, networking layer)
- [x] 01-03: Railway Deployment (deploy backend, configure PostgreSQL)
- [x] 01-04: End-to-End Verification (test iOS -> Backend -> Database)

**Key Decisions:**
- UUID primary keys for all models (better for distributed systems)
- Async SQLAlchemy throughout (scalability)
- SwiftData unidirectional relationships (avoids circular reference errors)
- Actor-based API client (thread-safety without locks)

---

### Phase 2: Authentication

**Goal**: Complete auth system with email/password, Apple Sign In, email verification, and password reset
**Depends on**: Phase 1
**Plans**: 6 plans

Plans:
- [x] 02-01: Backend JWT auth with access/refresh tokens
- [x] 02-02: Backend Email service integration for verification and password reset
- [x] 02-03: Backend Apple Sign In token validation
- [x] 02-04: iOS Email/password signup and login UI
- [x] 02-05: iOS Apple Sign In integration
- [x] 02-06: iOS Token storage in Keychain and session management

**Requirements Satisfied:** AUTH-01 through AUTH-12 (12 requirements)

---

### Phase 3: Video Capture (iOS)

**Goal**: iOS video capture from camera roll, YouTube URL paste, and Share Extension
**Depends on**: Phase 2
**Plans**: 6 plans

Plans:
- [x] 03-01: iOS PhotosPicker integration with permission handling
- [x] 03-02: iOS Video preview UI with thumbnail generation
- [x] 03-03: iOS YouTube-only URL input (TikTok/IG hidden for v1)
- [x] 03-04: iOS Share Extension target with App Group configuration
- [x] 03-05: iOS SwiftData shared container for pending uploads
- [x] 03-06: iOS Upload progress UI with cancellation

**Key Decisions:**
- PhotosPicker for video selection (native SwiftUI, no explicit permissions needed)
- Regex-based URL validation (simple, no dependencies)
- App Groups for Share Extension (required for shared SwiftData container)

**Requirements Satisfied:** CAPT-01 through CAPT-07, CAPT-11 (8 requirements)

---

### Phase 4: Transcription

**Goal**: Transcribe camera roll uploads via backend (Whisper/AssemblyAI), fetch YouTube captions
**Depends on**: Phase 3
**Plans**: 4 plans

Plans:
- [x] 04-01: Backend Video file upload endpoint with Whisper/AssemblyAI transcription
- [x] 04-02: Backend YouTube caption fetching via youtube-transcript-api
- [x] 04-03: iOS Video file upload to backend with progress indicator
- [x] 04-04: iOS Update UI to show YouTube-only URL support, hide TikTok/IG

**Key Decisions:**
- Server-side Whisper/AssemblyAI (macOS 13 can't build WhisperKit)
- youtube-transcript-api (no API key required, free captions)
- TikTok/IG URL support deferred to v2

**Requirements Satisfied:** CAPT-08 through CAPT-16, INFR-03 (9 requirements, CAPT-08 deferred)

---

### Phase 5: AI Summarization

**Goal**: Claude API integration to generate bullets, step-by-step checklists, cards, and tags
**Depends on**: Phase 4, Phase 2
**Plans**: 6 plans

Plans:
- [x] 05-01: Claude API service + Pydantic schemas (foundation)
- [x] 05-02: Bullet summaries + auto-tagging (free tier, Haiku)
- [x] 05-03: Add Pro summary fields to Video model + tier gating
- [x] 05-04: Pro format generation (steps + cards) with Sonnet
- [x] 05-05: Regeneration + quality checks with prompt caching
- [x] 05-06: Manual editing endpoint with user_edited protection

**Key Decisions:**
- AsyncAnthropic for Claude API (non-blocking async)
- tenacity for retries (exponential backoff with jitter)
- Claude Haiku for free tier (cost efficiency)
- Claude Sonnet for Pro formats (better reasoning)

**Requirements Satisfied:** SUMM-01 through SUMM-04, SUMM-09 through SUMM-11, INFR-04 (8 requirements)

---

### Phase 6: Playbooks & Organization

**Goal**: CRUD Playbooks, video assignment, search, deletion, and bulk operations
**Depends on**: Phase 5
**Plans**: 7 plans

Plans:
- [x] 06-01: Backend schema migration (one-to-many -> many-to-many + search_vector)
- [x] 06-02: iOS SwiftData models (many-to-many relationships)
- [x] 06-03: Backend Playbook CRUD API + Favorites Playbook
- [x] 06-04: Backend search endpoint + video-Playbook assignment
- [x] 06-05: Backend bulk operations (delete, move, add-to-favorites)
- [x] 06-06: iOS Playbook views (list, detail, picker sheet)
- [x] 06-07: iOS video grid (selection mode, search, bulk actions)

**Key Decisions:**
- video_playbooks association table (many-to-many)
- Weighted tsvector for search (tags > summary > transcript)
- GIN index for sub-millisecond FTS
- @Observable for ViewModels (iOS 17+ pattern)

**Requirements Satisfied:** PLAY-01 through PLAY-12 (12 requirements)

---

### Phase 7: Summary Display

**Goal**: iOS UI to display bullets, steps, cards with deep-linking to source videos
**Depends on**: Phase 5, Phase 8
**Plans**: 6 plans

Plans:
- [x] 07-01: iOS Summary models + SummaryViewModel
- [x] 07-02: DeepLinkService + InlineVideoPlayerView
- [x] 07-03: BulletSummaryView + StepChecklistView
- [x] 07-04: CardStackView + SwipeableCardView
- [x] 07-05: SummaryDisplayView container + Pro tier gating
- [x] 07-06: Navigation integration (gap closure)

**Key Decisions:**
- UserDefaults for step completion persistence
- 120pt swipe threshold for cards
- 4pt line spacing (ADHD-friendly)
- HTTPS-only deep links

**Requirements Satisfied:** SUMM-05 through SUMM-08 (4 requirements)

---

### Phase 8: Subscription System

**Goal**: RevenueCat integration with free/Pro tiers, usage tracking, and IAP
**Depends on**: Phase 2, Phase 5
**Plans**: 8 plans

Plans:
- [x] 08-01: Backend usage tracking schema
- [x] 08-02: Backend RevenueCat webhook handler
- [x] 08-03: Backend usage API and limit enforcement
- [x] 08-04: iOS RevenueCat SDK integration
- [x] 08-05: iOS usage tracking ViewModel
- [x] 08-06: iOS paywall UI with RevenueCatUI
- [x] 08-07: iOS usage indicator and detail sheet
- [x] 08-08: iOS restore purchases and tier wiring

**Requirements Satisfied:** SUBS-01 through SUBS-13, INFR-06 through INFR-07 (15 requirements)

---

### Phase 9: Habit Extraction

**Goal**: LLM extracts 1-3 habits from videos with Pro tier gating
**Depends on**: Phase 8, Phase 5
**Plans**: 4 plans

Plans:
- [x] 09-01: Backend habit extraction service + Pydantic schemas
- [x] 09-02: Backend habit API endpoints
- [x] 09-03: iOS models + APIClient + ViewModel
- [x] 09-04: iOS UI: HabitExtractionSheet + SummaryDisplayView integration

**Key Decisions:**
- Claude Sonnet for habit extraction (better reasoning)
- Structured outputs for guaranteed JSON
- Pro tier gate on both extraction AND creation

**Requirements Satisfied:** HABT-01 through HABT-04 (4 requirements)

---

### Phase 10: Habit Tracking

**Goal**: Local notifications, completions, streaks with 1-day forgiveness, visualization
**Depends on**: Phase 9
**Plans**: 7 plans

Plans:
- [x] 10-01: HabitCompletion model + schema migration
- [x] 10-02: Habit model updates (reminder_time, reminder_days, is_active)
- [x] 10-03: Habit completion endpoint + streak calculation with forgiveness
- [x] 10-04: NotificationManager + permission handling
- [x] 10-05: iOS HabitCompletion model + APIClient updates
- [x] 10-06: HabitListView + HabitRowView with streaks
- [x] 10-07: HabitDetailView (edit, delete, calendar visualization, source video link)

**Key Decisions:**
- Gap <= 2 for streak forgiveness (1 missed day allowed)
- UNCalendarNotificationTrigger for reminders
- Swift Charts for streak calendar

**Requirements Satisfied:** HABT-05 through HABT-17 (13 requirements)

---

### Phase 11: Infrastructure & Polish

**Goal**: Analytics, crash reporting, webhook retry, and production-grade error handling
**Depends on**: Phase 10
**Plans**: 6 plans

Plans:
- [x] 11-01: Backend logging infrastructure (Sentry + structlog + correlation IDs)
- [x] 11-02: Webhook retry queue with dead letter handling
- [x] 11-03: iOS crash reporting with Sentry
- [x] 11-04: iOS analytics with Mixpanel
- [x] 11-05: iOS user-friendly error handling
- [x] 11-06: LLM error handling with timeout and fallback

**Key Decisions:**
- JSON logs in production (Railway aggregation)
- 30-second timeout for LLM calls
- AppError enum for iOS (user-friendly messages)
- Webhook exponential backoff (5, 10, 20, 40, 80 min)

**Requirements Satisfied:** INFR-08 through INFR-10 (3 requirements)

---

### Phase 12: Legal & Launch Prep

**Goal**: Terms of Service, Privacy Policy, App Store submission materials
**Depends on**: Phase 11
**Plans**: 5 plans

Plans:
- [x] 12-01: Legal documents and backend hosting
- [x] 12-02: iOS WebView and Mail components
- [x] 12-03: iOS Legal links integration
- [x] 12-04: App Store Connect configuration (checkpoint)
- [x] 12-05: App Store marketing materials (visuals deferred)

**Key Decisions:**
- Root-level legal endpoints (/terms, /privacy)
- GDPR-compliant AI disclosure
- UIViewRepresentable for WebView
- Problem-focused App Store description

**Requirements Satisfied:** LEGA-01 through LEGA-06 (6 requirements)

---

## Milestone Summary

**Key Decisions:**
- SwiftUI + SwiftData for iOS (native performance)
- FastAPI + PostgreSQL on Railway (team familiarity, async support)
- Server-side transcription for v1 (macOS 14+ required for WhisperKit)
- RevenueCat for subscriptions (simplifies IAP)
- Sentry for crash reporting (SwiftUI screenshot support)
- Mixpanel for analytics (event tracking)

**Issues Resolved:**
- TikTok/IG URL support deferred to v2 (WhisperKit toolchain requires macOS 14+)
- Phase 7 navigation gap closed with plan 07-06
- Sentry User API conflict resolved (Sentry.User() vs local User model)

**Issues Deferred:**
- App Store screenshots and preview video (requires finalized UI)
- TikTok/Instagram URL transcription (requires macOS 14+)
- Offline habit tracking

**Technical Debt Incurred:**
- Source video navigation placeholder in HabitDetailView
- Analytics tracking limited to 3 events (could expand)

---

*Archived: 2026-01-28*
*For current project status, see .planning/ROADMAP.md*
