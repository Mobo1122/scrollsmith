# Requirements: Scrollsmith

**Defined:** 2026-01-18
**Core Value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Authentication

- [ ] **AUTH-01**: User can sign up with email and password
- [ ] **AUTH-02**: User receives email verification after signup
- [ ] **AUTH-03**: User can verify email via verification link
- [ ] **AUTH-04**: User can log in with email and password
- [ ] **AUTH-05**: User can sign in with Apple ID
- [ ] **AUTH-06**: User can request password reset via email
- [ ] **AUTH-07**: User can reset password via email link
- [ ] **AUTH-08**: User session persists across app launches
- [ ] **AUTH-09**: User can log out from settings
- [ ] **AUTH-10**: App shows error state for invalid credentials
- [ ] **AUTH-11**: App shows error state for network failures during auth
- [ ] **AUTH-12**: App shows loading spinner during signup/login/password reset

### Video Capture

- [ ] **CAPT-01**: User can upload video from camera roll via PhotosPicker (including downloaded Reels/Shorts)
- [ ] **CAPT-02**: App requests camera roll access permission with clear purpose
- [ ] **CAPT-03**: App shows error message if non-video media selected
- [ ] **CAPT-04**: User can preview video thumbnail before processing
- [ ] **CAPT-05**: User can paste YouTube URL to fetch captions (TikTok/IG URL deferred to v2)
- [ ] **CAPT-06**: App validates YouTube URL format and shows error for invalid links
- [ ] **CAPT-07**: User can share video to Scrollsmith via iOS Share Sheet from other apps
- [x] **CAPT-08**: ~~On-device transcription~~ **DEFERRED TO v2** (requires macOS 14+ for WhisperKit toolchain)
- [ ] **CAPT-09**: App transcribes camera roll uploads via backend (OpenAI Whisper API or AssemblyAI)
- [ ] **CAPT-10**: App fetches YouTube captions via youtube-transcript-api when available
- [ ] **CAPT-11**: App shows progress indicator during video upload
- [ ] **CAPT-12**: App shows progress indicator during transcription
- [ ] **CAPT-13**: App handles network errors during upload with retry option
- [ ] **CAPT-14**: App shows "Transcript unavailable" for YouTube videos without captions (no fallback in v1)
- [ ] **CAPT-15**: App stores transcript and metadata only (no permanent video storage)
- [ ] **CAPT-16**: App deletes uploaded video file from server after transcription completes

### Summarization

- [ ] **SUMM-01**: App generates bullet point summary for every captured video
- [ ] **SUMM-02**: App generates step-by-step checklist with timestamps (Pro tier)
- [ ] **SUMM-03**: App generates swipeable card format summary (Pro tier)
- [ ] **SUMM-04**: App auto-generates tags from video content
- [ ] **SUMM-05**: User can view bullet summary for any saved video
- [ ] **SUMM-06**: User can view step-by-step checklist for any saved video (Pro tier)
- [ ] **SUMM-07**: User can view swipeable cards for any saved video (Pro tier)
- [ ] **SUMM-08**: User can deep-link to original video source from summary view
- [ ] **SUMM-09**: User can manually regenerate summary if quality is poor
- [ ] **SUMM-10**: App handles poor transcription quality with retry/warning
- [ ] **SUMM-11**: User can edit summary manually if needed

### Playbooks & Organization

- [ ] **PLAY-01**: User can create a new Playbook with custom name
- [ ] **PLAY-02**: User can edit Playbook name
- [ ] **PLAY-03**: User can delete a Playbook (videos move to uncategorized)
- [ ] **PLAY-04**: User can assign a video to a Playbook during or after capture
- [ ] **PLAY-05**: User can view all videos in a specific Playbook
- [ ] **PLAY-06**: User can view all uncategorized videos
- [ ] **PLAY-07**: User can edit auto-generated tags on any video
- [ ] **PLAY-08**: User can search across all videos by title, transcript, or tags
- [ ] **PLAY-09**: User can delete a video permanently
- [ ] **PLAY-10**: App confirms before permanent video deletion
- [ ] **PLAY-11**: User can bulk select and delete multiple videos
- [ ] **PLAY-12**: User can bulk move videos to different Playbook

### Habits (Pro Tier)

- [x] **HABT-01**: User can tap "Make action points" on any summarized video
- [x] **HABT-02**: App suggests 1-3 concrete recurring habits based on video content
- [x] **HABT-03**: User can select which suggested habits to create
- [x] **HABT-04**: User can set habit frequency (daily, 3×weekly, weekly)
- [ ] **HABT-05**: User can set reminder time for each habit
- [ ] **HABT-06**: App requests push notification permission with clear value proposition
- [ ] **HABT-07**: App provides in-app habit reminder UI if notifications denied
- [ ] **HABT-08**: User receives push notification reminder at scheduled time
- [ ] **HABT-09**: User can mark habit complete from push notification
- [ ] **HABT-10**: User can mark habit complete from app
- [ ] **HABT-11**: App tracks current streak for each habit
- [ ] **HABT-12**: App tracks longest streak for each habit
- [ ] **HABT-13**: App implements 1-day streak forgiveness (miss 1 day without losing streak)
- [ ] **HABT-14**: User can view all habits in a list with streaks visualized (calendar/chart)
- [ ] **HABT-15**: User can view habit linked to its source video
- [ ] **HABT-16**: User can edit habit details (title, frequency, reminder time) post-creation
- [ ] **HABT-17**: User can delete a habit

### Subscription

- [ ] **SUBS-01**: Free tier limits user to 10 videos per month
- [ ] **SUBS-02**: Free tier provides bullet summaries only
- [ ] **SUBS-03**: Free tier video count resets on first of month
- [ ] **SUBS-04**: App blocks new video processing at 11th video with upgrade prompt
- [ ] **SUBS-05**: Pro tier unlocks unlimited videos (100+/month)
- [ ] **SUBS-06**: Pro tier unlocks all summary formats (bullets, steps, cards)
- [ ] **SUBS-07**: Pro tier unlocks habit extraction and tracking
- [ ] **SUBS-08**: App shows current usage (X/10 videos this month) for free tier
- [ ] **SUBS-09**: App prompts upgrade when free tier limit reached
- [ ] **SUBS-10**: User can purchase Pro subscription via Apple IAP
- [ ] **SUBS-11**: User can restore previous purchases
- [ ] **SUBS-12**: App verifies subscription status with backend via RevenueCat API
- [ ] **SUBS-13**: App includes sandbox IAP testing capability

### Infrastructure

- [ ] **INFR-01**: Backend API deployed and accessible from iOS app
- [ ] **INFR-02**: PostgreSQL database stores users, videos, habits, subscriptions
- [ ] **INFR-03**: Backend integrates with OpenAI Whisper API for transcription
- [ ] **INFR-04**: Backend integrates with Anthropic Claude API for summarization
- [ ] **INFR-05**: Backend integrates with YouTube Data API for captions
- [ ] **INFR-06**: Backend integrates with RevenueCat for subscription validation
- [ ] **INFR-07**: Backend handles RevenueCat webhooks for subscription events
- [ ] **INFR-08**: Backend implements webhook retry logic for failed events
- [ ] **INFR-09**: App includes crash reporting (Sentry or similar)
- [ ] **INFR-10**: App includes analytics tracking (video views, habit completions, conversions)

### Legal & Support

- [ ] **LEGA-01**: App includes Terms of Service
- [ ] **LEGA-02**: App includes Privacy Policy
- [ ] **LEGA-03**: Privacy Policy link accessible from signup screen
- [ ] **LEGA-04**: Terms link accessible from signup screen
- [ ] **LEGA-05**: App Store Connect agreements signed and products "Ready to Submit"
- [ ] **LEGA-06**: App includes customer support contact email in settings

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### TikTok/Instagram URL Support (v2)

- **TIKT-01**: User can paste TikTok URL to import video
- **TIKT-02**: User can paste Instagram Reels URL to import video
- **TIKT-03**: iOS downloads media from TikTok/IG URLs on-device
- **TIKT-04**: iOS transcribes TikTok/IG videos on-device using WhisperKit (iOS 17+)
- **TIKT-05**: iOS fallback to Apple Speech Framework for older devices

**Note:** Requires macOS 14+ development environment for WhisperKit toolchain. For v1, users should download TikTok/IG videos to camera roll and upload from there.

### Weekly Synthesis

- **SYNT-01**: App generates weekly digest email summarizing saved content patterns
- **SYNT-02**: Weekly digest includes habit completion summary
- **SYNT-03**: User can configure weekly digest preferences

### Enhanced Organization

- **ORGZ-01**: Default Playbooks pre-created (Business, Fitness, Cooking, Productivity, Mindset)
- **ORGZ-02**: Progress visualization per Playbook (videos saved, habits completed)

### Additional Auth

- **AUTH-06**: Magic link passwordless login

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Android app | iOS-first strategy; platform expansion after v1 validation |
| Web app with features | Mobile-only for v1; marketing site only |
| Social sharing | Single-user focus; adds complexity without core value |
| Collaborative Playbooks | Multi-user complexity; defer to v2+ |
| Video editing | Not core value; users want to consume and act, not edit |
| Community features | Not core value; personal organization tool |
| Video downloading from URLs | Legal concerns, storage costs; transcript-only approach |
| Offline video playback | Not storing videos; deep-link to platforms instead |
| Gamification with penalties | ADHD users respond poorly; streaks with forgiveness instead |
| Unlimited habit tracking per video | Research shows 1-3 habits max is effective |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFR-01 to INFR-02 | Phase 1 | Complete |
| AUTH-01 to AUTH-12 | Phase 2 | Complete |
| CAPT-01 to CAPT-07, CAPT-11 | Phase 3 | Complete |
| CAPT-08 to CAPT-10, CAPT-12 to CAPT-16, INFR-03, INFR-05 | Phase 4 | Complete |
| SUMM-01 to SUMM-04, SUMM-09 to SUMM-11, INFR-04 | Phase 5 | Complete |
| PLAY-01 to PLAY-12 | Phase 6 | Complete |
| SUMM-05 to SUMM-08 | Phase 7 | Complete |
| SUBS-01 to SUBS-13, INFR-06 to INFR-07 | Phase 8 | Pending |
| HABT-01 to HABT-04 | Phase 9 | Complete |
| HABT-05 to HABT-17 | Phase 10 | Pending |
| INFR-08 to INFR-10 | Phase 11 | Pending |
| LEGA-01 to LEGA-06 | Phase 12 | Pending |

**Coverage:**
- v1 requirements: 85 total
- Mapped to phases: 85
- Unmapped: 0 ✓

---
*Requirements defined: 2026-01-18*
*Last updated: 2026-01-26 - Phase 9 Habit Extraction complete*
