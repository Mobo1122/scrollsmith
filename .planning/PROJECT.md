# Scrollsmith

## What This Is

Scrollsmith is an ADHD-friendly iOS app that transforms saved short-form videos (YouTube Shorts, camera-roll uploads including downloaded TikTok/Reels) into organized Playbooks with AI-generated summaries and actionable habits. Users capture scattered video inspiration, get structured summaries (bullets, step-by-step checklists, swipeable cards), organize content into themed Playbooks, and convert insights into trackable recurring habits with reminders and streak tracking.

## Core Value

Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits, addressing ADHD challenges of information overload, action paralysis, and memory issues.

## Current State

**v1 MVP shipped: 2026-01-28**

- iOS app: SwiftUI + SwiftData (13,128 LOC)
- Backend: FastAPI + PostgreSQL on Railway (6,963 LOC)
- 85 requirements satisfied
- App Store submission pending (screenshots/video needed)

See [MILESTONES.md](MILESTONES.md) for v1 details.

## Requirements

### Validated

- ✓ Users can capture videos via camera-roll upload, YouTube URL paste, or iOS share sheet — v1
- ✓ Backend transcribes camera roll videos (Whisper/AssemblyAI) and fetches YouTube captions — v1
- ✓ Backend generates three summary formats: key bullets, step-by-step checklist with timestamps, and swipeable cards — v1
- ✓ Videos are organized into Playbooks with auto-generated tags users can edit — v1
- ✓ Users can create 1-3 concrete recurring habits from any summarized video with customizable frequency and reminder times — v1
- ✓ App tracks habit completions and streaks with 1-day forgiveness — v1
- ✓ Free tier: 10 videos/month, bullet summaries only, auto-tags + playbooks, no habit extraction — v1
- ✓ Pro tier (subscription): unlimited videos, all summary formats, habit extraction — v1
- ✓ Apple Sign In and email/password authentication — v1
- ✓ Push notifications for habit reminders with quick completion — v1
- ✓ Terms of Service and Privacy Policy — v1
- ✓ Crash reporting (Sentry) and analytics (Mixpanel) — v1

### Active

- [ ] TikTok/Instagram URL paste with on-device WhisperKit transcription (deferred from v1 — requires macOS 14+)
- [ ] Weekly LLM-generated digest email
- [ ] Marketing landing page for App Store conversion

### Out of Scope

- Android app — iOS-first, platform expansion deferred to v2+
- Social sharing or collaborative Playbooks — single-user experience
- Web app with feature parity — mobile-only (marketing site only)
- Real-time chat or community features — focus is personal organization and habits
- Video editing capabilities — content is consumed and summarized, not modified

## Context

**ADHD-Specific Design:**
- Solving information overload (saved videos users never revisit)
- Addressing action paralysis (great advice that never becomes habits)
- Mitigating memory issues (forgetting video content or why it was saved)

**Technical Environment:**
- iOS 17+ minimum
- SwiftUI + SwiftData native app
- Python/FastAPI backend on Railway
- PostgreSQL database
- RevenueCat for subscriptions (Apple IAP)
- Sentry for crash reporting, Mixpanel for analytics

**Video Processing (v1):**
- **Camera-roll uploads:** iOS uploads video → Backend transcribes via Whisper/AssemblyAI → Deletes file
- **YouTube URLs:** Backend fetches captions via youtube-transcript-api
- **TikTok/Instagram URLs:** Deferred to v2 (requires macOS 14+ for WhisperKit)

**AI Stack:**
- OpenAI Whisper API or AssemblyAI for transcription
- youtube-transcript-api for YouTube captions
- Anthropic Claude (Haiku for bullets, Sonnet for Pro formats and habits)

## Constraints

- **Platform**: iOS 17+ only
- **Backend**: Python/FastAPI on Railway with PostgreSQL
- **Monetization**: Apple IAP via RevenueCat
- **LLM Provider**: Anthropic Claude
- **Transcription**: Server-side Whisper/AssemblyAI for v1

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI native (not React Native) | Best iOS performance, access to latest Apple frameworks | ✓ Good |
| Transcript-only storage for URL videos | Privacy-friendly, cost-efficient, lean architecture | ✓ Good |
| Server-side transcription for v1 | macOS 13 dev environment cannot build WhisperKit | ✓ Good (workaround) |
| TikTok/IG URL support deferred to v2 | On-device WhisperKit requires macOS 14+ toolchain | ✓ Good (clear tradeoff) |
| youtube-transcript-api for YouTube | No API key needed, free captions | ✓ Good |
| RevenueCat for subscriptions | Simplifies IAP implementation | ✓ Good |
| Free tier at 10 videos/month | Enough to prove value without being punitive | — Pending validation |
| Sentry for iOS crash reporting | SwiftUI screenshot support, view hierarchy capture | ✓ Good |
| Mixpanel for analytics | Event tracking, user identification | ✓ Good |
| Claude Haiku for free tier | Cost efficiency ($1/$5 per MTok) | ✓ Good |
| Claude Sonnet for Pro formats | Better reasoning for complex extraction | ✓ Good |
| 1-day streak forgiveness | ADHD users need grace period | ✓ Good (per RESEARCH.md) |

---
*Last updated: 2026-01-28 after v1 milestone*
