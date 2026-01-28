# Requirements Archive: v1 MVP

**Archived:** 2026-01-28
**Status:** ✅ SHIPPED

This is the archived requirements specification for v1.
For current requirements, see `.planning/REQUIREMENTS.md` (created for next milestone).

---

# Requirements: Scrollsmith

**Defined:** 2026-01-18
**Core Value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits.

## v1 Requirements

Requirements for initial release. All mapped to roadmap phases and shipped.

### Authentication

- [x] **AUTH-01**: User can sign up with email and password
- [x] **AUTH-02**: User receives email verification after signup
- [x] **AUTH-03**: User can verify email via verification link
- [x] **AUTH-04**: User can log in with email and password
- [x] **AUTH-05**: User can sign in with Apple ID
- [x] **AUTH-06**: User can request password reset via email
- [x] **AUTH-07**: User can reset password via email link
- [x] **AUTH-08**: User session persists across app launches
- [x] **AUTH-09**: User can log out from settings
- [x] **AUTH-10**: App shows error state for invalid credentials
- [x] **AUTH-11**: App shows error state for network failures during auth
- [x] **AUTH-12**: App shows loading spinner during signup/login/password reset

### Video Capture

- [x] **CAPT-01**: User can upload video from camera roll via PhotosPicker (including downloaded Reels/Shorts)
- [x] **CAPT-02**: App requests camera roll access permission with clear purpose
- [x] **CAPT-03**: App shows error message if non-video media selected
- [x] **CAPT-04**: User can preview video thumbnail before processing
- [x] **CAPT-05**: User can paste YouTube URL to fetch captions (TikTok/IG URL deferred to v2)
- [x] **CAPT-06**: App validates YouTube URL format and shows error for invalid links
- [x] **CAPT-07**: User can share video to Scrollsmith via iOS Share Sheet from other apps
- [x] **CAPT-08**: ~~On-device transcription~~ **DEFERRED TO v2** (requires macOS 14+ for WhisperKit toolchain)
- [x] **CAPT-09**: App transcribes camera roll uploads via backend (OpenAI Whisper API or AssemblyAI)
- [x] **CAPT-10**: App fetches YouTube captions via youtube-transcript-api when available
- [x] **CAPT-11**: App shows progress indicator during video upload
- [x] **CAPT-12**: App shows progress indicator during transcription
- [x] **CAPT-13**: App handles network errors during upload with retry option
- [x] **CAPT-14**: App shows "Transcript unavailable" for YouTube videos without captions (no fallback in v1)
- [x] **CAPT-15**: App stores transcript and metadata only (no permanent video storage)
- [x] **CAPT-16**: App deletes uploaded video file from server after transcription completes

### Summarization

- [x] **SUMM-01**: App generates bullet point summary for every captured video
- [x] **SUMM-02**: App generates step-by-step checklist with timestamps (Pro tier)
- [x] **SUMM-03**: App generates swipeable card format summary (Pro tier)
- [x] **SUMM-04**: App auto-generates tags from video content
- [x] **SUMM-05**: User can view bullet summary for any saved video
- [x] **SUMM-06**: User can view step-by-step checklist for any saved video (Pro tier)
- [x] **SUMM-07**: User can view swipeable cards for any saved video (Pro tier)
- [x] **SUMM-08**: User can deep-link to original video source from summary view
- [x] **SUMM-09**: User can manually regenerate summary if quality is poor
- [x] **SUMM-10**: App handles poor transcription quality with retry/warning
- [x] **SUMM-11**: User can edit summary manually if needed

### Playbooks & Organization

- [x] **PLAY-01**: User can create a new Playbook with custom name
- [x] **PLAY-02**: User can edit Playbook name
- [x] **PLAY-03**: User can delete a Playbook (videos move to uncategorized)
- [x] **PLAY-04**: User can assign a video to a Playbook during or after capture
- [x] **PLAY-05**: User can view all videos in a specific Playbook
- [x] **PLAY-06**: User can view all uncategorized videos
- [x] **PLAY-07**: User can edit auto-generated tags on any video
- [x] **PLAY-08**: User can search across all videos by title, transcript, or tags
- [x] **PLAY-09**: User can delete a video permanently
- [x] **PLAY-10**: App confirms before permanent video deletion
- [x] **PLAY-11**: User can bulk select and delete multiple videos
- [x] **PLAY-12**: User can bulk move videos to different Playbook

### Habits (Pro Tier)

- [x] **HABT-01**: User can tap "Make action points" on any summarized video
- [x] **HABT-02**: App suggests 1-3 concrete recurring habits based on video content
- [x] **HABT-03**: User can select which suggested habits to create
- [x] **HABT-04**: User can set habit frequency (daily, 3×weekly, weekly)
- [x] **HABT-05**: User can set reminder time for each habit
- [x] **HABT-06**: App requests push notification permission with clear value proposition
- [x] **HABT-07**: App provides in-app habit reminder UI if notifications denied
- [x] **HABT-08**: User receives push notification reminder at scheduled time
- [x] **HABT-09**: User can mark habit complete from push notification
- [x] **HABT-10**: User can mark habit complete from app
- [x] **HABT-11**: App tracks current streak for each habit
- [x] **HABT-12**: App tracks longest streak for each habit
- [x] **HABT-13**: App implements 1-day streak forgiveness (miss 1 day without losing streak)
- [x] **HABT-14**: User can view all habits in a list with streaks visualized (calendar/chart)
- [x] **HABT-15**: User can view habit linked to its source video
- [x] **HABT-16**: User can edit habit details (title, frequency, reminder time) post-creation
- [x] **HABT-17**: User can delete a habit

### Subscription

- [x] **SUBS-01**: Free tier limits user to 10 videos per month
- [x] **SUBS-02**: Free tier provides bullet summaries only
- [x] **SUBS-03**: Free tier video count resets on first of month
- [x] **SUBS-04**: App blocks new video processing at 11th video with upgrade prompt
- [x] **SUBS-05**: Pro tier unlocks unlimited videos (100+/month)
- [x] **SUBS-06**: Pro tier unlocks all summary formats (bullets, steps, cards)
- [x] **SUBS-07**: Pro tier unlocks habit extraction and tracking
- [x] **SUBS-08**: App shows current usage (X/10 videos this month) for free tier
- [x] **SUBS-09**: App prompts upgrade when free tier limit reached
- [x] **SUBS-10**: User can purchase Pro subscription via Apple IAP
- [x] **SUBS-11**: User can restore previous purchases
- [x] **SUBS-12**: App verifies subscription status with backend via RevenueCat API
- [x] **SUBS-13**: App includes sandbox IAP testing capability

### Infrastructure

- [x] **INFR-01**: Backend API deployed and accessible from iOS app
- [x] **INFR-02**: PostgreSQL database stores users, videos, habits, subscriptions
- [x] **INFR-03**: Backend integrates with OpenAI Whisper API for transcription
- [x] **INFR-04**: Backend integrates with Anthropic Claude API for summarization
- [x] **INFR-05**: Backend integrates with YouTube Data API for captions
- [x] **INFR-06**: Backend integrates with RevenueCat for subscription validation
- [x] **INFR-07**: Backend handles RevenueCat webhooks for subscription events
- [x] **INFR-08**: Backend implements webhook retry logic for failed events
- [x] **INFR-09**: App includes crash reporting (Sentry or similar)
- [x] **INFR-10**: App includes analytics tracking (video views, habit completions, conversions)

### Legal & Support

- [x] **LEGA-01**: App includes Terms of Service
- [x] **LEGA-02**: App includes Privacy Policy
- [x] **LEGA-03**: Privacy Policy link accessible from signup screen
- [x] **LEGA-04**: Terms link accessible from signup screen
- [x] **LEGA-05**: App Store Connect agreements signed and products "Ready to Submit"
- [x] **LEGA-06**: App includes customer support contact email in settings

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFR-01 to INFR-02 | Phase 1 | Complete |
| AUTH-01 to AUTH-12 | Phase 2 | Complete |
| CAPT-01 to CAPT-07, CAPT-11 | Phase 3 | Complete |
| CAPT-08 to CAPT-10, CAPT-12 to CAPT-16, INFR-03, INFR-05 | Phase 4 | Complete |
| SUMM-01 to SUMM-04, SUMM-09 to SUMM-11, INFR-04 | Phase 5 | Complete |
| PLAY-01 to PLAY-12 | Phase 6 | Complete |
| SUMM-05 to SUMM-08 | Phase 7 | Complete |
| SUBS-01 to SUBS-13, INFR-06 to INFR-07 | Phase 8 | Complete |
| HABT-01 to HABT-04 | Phase 9 | Complete |
| HABT-05 to HABT-17 | Phase 10 | Complete |
| INFR-08 to INFR-10 | Phase 11 | Complete |
| LEGA-01 to LEGA-06 | Phase 12 | Complete |

**Coverage:**
- v1 requirements: 85 total
- Shipped: 85 (100%)
- Deferred to v2: 1 (CAPT-08 on-device transcription)

---

## Milestone Summary

**Shipped:** 85 of 85 v1 requirements

**Adjusted During Implementation:**
- CAPT-08 (On-device transcription): Deferred to v2 due to macOS 14+ requirement for WhisperKit toolchain. Server-side transcription (CAPT-09) used instead.
- CAPT-05: Originally included TikTok/IG URLs, updated to YouTube-only for v1.

**Dropped:** None

---

*Archived: 2026-01-28 as part of v1 milestone completion*
