# Research Summary: Scrollsmith

**Synthesized:** 2026-01-18

## TL;DR

Build with **SwiftUI + SwiftData** (iOS 17+), **WhisperKit** for on-device transcription, **FastAPI + async SQLAlchemy** backend, **Claude 3.5 Sonnet** for summaries, **RevenueCat** for subscriptions. Key risks: Share Extension memory limits, LLM cost explosion, timezone streak bugs. Unique position: No competitor connects video curation → AI summaries → habit extraction.

---

## Stack Recommendations

### iOS Client
| Need | Use | Why |
|------|-----|-----|
| UI | SwiftUI | Native, iOS 17+ features |
| Local DB | SwiftData | Replaces Core Data complexity, SwiftUI integration |
| Transcription (iOS 18+) | WhisperKit | Apple-optimized Whisper, on-device |
| Transcription (iOS 17) | Apple Speech Framework | Fallback, good enough accuracy |
| Subscriptions | RevenueCat SDK | Handles StoreKit 1/2, receipts |

### Backend
| Need | Use | Why |
|------|-----|-----|
| Framework | FastAPI 0.115+ | Async-first, fast |
| ORM | SQLAlchemy 2.0 async + asyncpg | Non-blocking DB ops |
| LLM | Anthropic Claude 3.5 Sonnet | Best structured output |
| Transcription | OpenAI Whisper API | For camera roll uploads |
| Hosting | Railway | Easy, Postgres included |

### External Services
- **RevenueCat** — Subscription management
- **S3/R2** — Rare video storage (camera roll only)
- **YouTube Data API** — Caption extraction
- **APNs** — Push notifications (optional)

---

## Feature Priorities

### Must Ship (Table Stakes)
- Share sheet capture
- Camera roll upload
- URL paste (TikTok/IG/YouTube)
- Playbooks + auto-tags
- Bullet summaries
- Apple Sign In + email/password
- Free/Pro subscription

### Core Differentiators
- Step-by-step checklists with timestamps
- Swipeable card summaries
- **"Make action points" → habit extraction** (unique)
- Streak tracking with forgiveness
- Weekly synthesis digest (Pro)

### Do NOT Build
- Social sharing / collaborative Playbooks
- Video editing
- Gamification with penalties
- Unlimited habit tracking (cap at 1-3 per video)

---

## Architecture Highlights

```
iOS Share Extension → App Group → Main App → Backend API
                                      ↓
                        On-device transcription (TikTok/IG)
                                      ↓
                        Backend: Claude summaries + habits
                                      ↓
                        PostgreSQL + S3 (transcripts, not videos)
```

**Key decisions:**
- Transcript-only storage for URL videos (privacy, cost, legal)
- On-device transcription for TikTok/IG (no video leaves device)
- Local notifications for habits (simpler than backend push)
- SwiftData with App Group for Share Extension sync

---

## Critical Pitfalls to Avoid

| Pitfall | Risk | Prevention |
|---------|------|------------|
| **Share Extension memory crash** | High | Don't process in extension; save to App Group, process in main app |
| **WhisperKit model size** | High | Ship tiny model, download larger on-demand |
| **LLM cost explosion** | High | Truncate transcripts, cache summaries, rate limit |
| **YouTube API quota** | Medium | Cache aggressively, apply for higher quota |
| **Timezone streak bugs** | High | Store timezone with completion, use 48-hour grace window |
| **RevenueCat webhook delays** | Medium | Verify entitlements server-side, don't trust client |

---

## Build Order

1. **Foundation** — FastAPI + PostgreSQL + iOS project
2. **Auth** — Apple Sign In + email/password
3. **Video Capture** — Share extension, camera roll, URL paste, on-device transcription
4. **Backend Processing** — Whisper API, Claude summaries, YouTube captions
5. **Playbooks** — CRUD, tags, search
6. **Summary Display** — Bullets, steps, cards
7. **Habits** — Extraction, notifications, streaks
8. **Subscriptions** — RevenueCat, feature gating
9. **Pro Features** — Weekly synthesis
10. **Polish** — Onboarding, analytics, launch

---

## Competitive Gap Scrollsmith Fills

| Competitor | What They Do | What They Miss |
|------------|--------------|----------------|
| Pocket | Bookmarking | Shutting down, no AI, no habits |
| Readwise Reader | Highlights, YouTube transcripts | $9/month, no habit extraction |
| Streaks | Beautiful habit tracking | No content source |
| Focus Bear | ADHD habits | No video capture |

**Scrollsmith's unique position:** Video capture → AI summarization → Habit extraction → Streak tracking. No one does this end-to-end for short-form video.

---

## Key Metrics to Track

1. **Retention** — DAU/WAU, return rate
2. **Conversion** — Free → Pro upgrade rate
3. **Habit completion** — Are users actually doing habits?
4. **Videos per user** — Library growth over time
5. **LLM cost per user** — API spend attribution
