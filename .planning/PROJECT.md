# Scrollsmith

## What This Is

Scrollsmith is an ADHD-friendly iOS app that transforms saved short-form videos (TikTok, Instagram Reels, YouTube Shorts, camera-roll uploads) into organized Playbooks with AI-generated summaries and actionable habits. Users capture scattered video inspiration, get structured summaries (bullets, step-by-step checklists, swipeable cards), organize content into themed Playbooks, and convert insights into trackable recurring habits with reminders and streak tracking.

## Core Value

Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits, addressing ADHD challenges of information overload, action paralysis, and memory issues.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Users can capture videos via camera-roll upload, paste-link (TikTok/IG/YouTube), or iOS share sheet
- [ ] Backend transcribes videos and generates three summary formats: key bullets, step-by-step checklist with timestamps, and swipeable cards
- [ ] Videos are organized into Playbooks (Business, Fitness, Cooking, Productivity, Mindset) with auto-generated tags users can edit
- [ ] Users can create 1-3 concrete recurring habits from any summarized video with customizable frequency (daily/3×weekly/weekly) and reminder times
- [ ] App tracks habit completions, streaks, and shows progress per Playbook
- [ ] Free tier: 10 videos/month, bullet summaries only, auto-tags + playbooks, no habit extraction
- [ ] Pro tier (subscription): 100+ videos/month, all summary formats, habit mode, weekly LLM-generated digest email
- [ ] Apple Sign In and email/password authentication
- [ ] Push notifications for habit reminders with quick completion check-off
- [ ] Marketing landing page for App Store conversion

### Out of Scope

- Android app — iOS-first, platform expansion deferred to v2+
- Social sharing or collaborative Playbooks — single-user experience for v1
- Web app with feature parity — mobile-only for v1 (marketing site only)
- Real-time chat or community features — focus is personal organization and habits
- Video editing capabilities — content is consumed and summarized, not modified

## Context

**ADHD-Specific Design:**
- Solving information overload (saved videos users never revisit)
- Addressing action paralysis (great advice that never becomes habits)
- Mitigating memory issues (forgetting video content or why it was saved)

**Technical Environment:**
- iOS 17+ minimum (iOS 18+ for on-device Whisper transcription)
- SwiftUI native app for best iOS performance
- Python/FastAPI backend deployed on Railway
- PostgreSQL database for structured data
- RevenueCat for subscription management (Apple IAP)

**Video Processing Strategy (v1):**
- **Camera-roll uploads** (including downloaded TikTok/IG/YouTube Shorts):
  - iOS uploads video/audio file to backend
  - Backend transcribes via OpenAI Whisper API or AssemblyAI
  - Backend deletes file immediately after transcription
  - Store only transcript + summaries + metadata
- **YouTube URLs:**
  - Backend fetches captions via youtube-transcript-api (no API key needed)
  - If no captions available, show "Transcript unavailable" message
- **TikTok/Instagram URLs:** **DEFERRED TO v2**
  - Requires macOS 14+ for WhisperKit toolchain (dev machine is macOS 13)
  - For v1, users download TikTok/IG videos to camera roll and upload from there

**AI Stack:**
- OpenAI Whisper API or AssemblyAI for audio transcription (camera-roll uploads only)
- youtube-transcript-api for YouTube captions (free, no API key)
- Anthropic Claude for summaries, tags, habit extraction, weekly synthesis

**Privacy-First:**
- Minimal server-side video storage (transcripts and metadata only)
- Video files deleted immediately after transcription
- v2 will add on-device WhisperKit transcription for TikTok/IG URLs

## Constraints

- **Platform**: iOS 17+ only — Ensures access to modern SwiftUI and Apple Speech Framework; iOS 18+ unlocks on-device Whisper
- **Backend**: Python/FastAPI on Railway with PostgreSQL — Full control over API design, good for LLM integrations and async processing
- **Storage**: S3 or similar for rare video storage (camera-roll only when needed) — Cost-conscious approach, prefer transcript storage
- **Monetization**: Apple IAP via RevenueCat — Required for iOS subscriptions, handles receipt validation and webhooks
- **LLM Provider**: Anthropic Claude — Strong structured output for summaries, tags, and habit extraction
- **Transcription**: OpenAI Whisper for uploads, on-device for social links — Balance between accuracy and privacy

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI native (not React Native) | Best iOS performance, access to latest Apple frameworks, pure native experience | — Pending |
| Transcript-only storage for URL videos | Privacy-friendly, cost-efficient, lean architecture | — Pending |
| Server-side transcription for v1 | macOS 13 dev environment cannot build WhisperKit (requires macOS 14+) | — Active |
| TikTok/IG URL support deferred to v2 | On-device WhisperKit requires macOS 14+ toolchain; users download to camera roll for v1 | — Active |
| youtube-transcript-api for YouTube | No API key needed, free captions, handles rate limits gracefully | — Active |
| RevenueCat for subscriptions | Simplifies IAP implementation, handles receipt validation, analytics | — Pending |
| Python/FastAPI backend | Team familiarity, excellent async support, good LLM integration ecosystem | — Pending |
| Free tier at 10 videos/month | Enough to prove value without being punitive, drives Pro conversion | — Pending |

---
*Last updated: 2026-01-23 - deferred TikTok/IG URL support to v2 (macOS 14+ required for WhisperKit)*
