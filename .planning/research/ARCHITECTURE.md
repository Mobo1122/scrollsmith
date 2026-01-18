# Architecture Research: Scrollsmith

**Researched:** 2026-01-18
**Domain:** iOS app + Python backend + AI integration

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ Share Ext   │  │ Main App    │  │ Notification│             │
│  │ (Capture)   │  │ (Browse/    │  │ Extension   │             │
│  │             │  │  Habits)    │  │             │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│  ┌──────┴────────────────┴────────────────┴──────┐             │
│  │              App Group (Shared Data)          │             │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐    │             │
│  │  │SwiftData │  │Keychain  │  │UserDefaults│   │             │
│  │  └──────────┘  └──────────┘  └──────────┘    │             │
│  └───────────────────────────────────────────────┘             │
│                           │                                     │
│  ┌────────────────────────┴────────────────────────┐           │
│  │              On-Device Processing               │           │
│  │  ┌──────────────┐  ┌──────────────┐            │           │
│  │  │ WhisperKit   │  │ Apple Speech │            │           │
│  │  │ (iOS 18+)    │  │ (iOS 17)     │            │           │
│  │  └──────────────┘  └──────────────┘            │           │
│  └─────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/REST
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FastAPI Backend (Railway)                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ Auth API    │  │ Videos API  │  │ Habits API  │             │
│  │ /auth/*     │  │ /videos/*   │  │ /habits/*   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                │                │                     │
│  ┌──────┴────────────────┴────────────────┴──────┐             │
│  │              Service Layer                    │             │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐    │             │
│  │  │ LLM Svc  │  │Transcribe│  │ Habit Svc│    │             │
│  │  │ (Claude) │  │ (Whisper)│  │          │    │             │
│  │  └──────────┘  └──────────┘  └──────────┘    │             │
│  └───────────────────────────────────────────────┘             │
│                           │                                     │
│  ┌────────────────────────┴────────────────────────┐           │
│  │              Data Layer (SQLAlchemy)            │           │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │           │
│  │  │ Users    │  │ Videos   │  │ Habits   │      │           │
│  │  │ Repo     │  │ Repo     │  │ Repo     │      │           │
│  │  └──────────┘  └──────────┘  └──────────┘      │           │
│  └─────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      External Services                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │PostgreSQL│  │ S3/R2    │  │ OpenAI   │  │Anthropic │       │
│  │ (Railway)│  │ (Storage)│  │ Whisper  │  │ Claude   │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                      │
│  │RevenueCat│  │ APNs     │  │ YouTube  │                      │
│  │          │  │          │  │ Data API │                      │
│  └──────────┘  └──────────┘  └──────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

## Component Boundaries

### iOS App Components

| Component | Responsibility | Talks To |
|-----------|---------------|----------|
| **Share Extension** | Capture videos from other apps | App Group, Main App |
| **Main App** | Browse, view summaries, manage habits | Backend API, Local DB |
| **Notification Extension** | Rich notifications for habits | Local DB |
| **On-Device Transcription** | Transcribe TikTok/IG locally | Backend (transcript only) |
| **SwiftData** | Local cache of videos, habits, summaries | Synced with backend |
| **RevenueCat SDK** | Subscription state | RevenueCat servers |

### Backend Components

| Component | Responsibility | Talks To |
|-----------|---------------|----------|
| **Auth API** | Register, login, token refresh | PostgreSQL, Apple Sign In |
| **Videos API** | CRUD videos, trigger processing | PostgreSQL, S3, LLM Service |
| **Habits API** | CRUD habits, log completions | PostgreSQL |
| **Subscriptions API** | Verify entitlements | RevenueCat webhook |
| **LLM Service** | Generate summaries, tags, habits | Anthropic Claude API |
| **Transcription Service** | Transcribe uploaded audio | OpenAI Whisper API |
| **Notification Service** | Schedule push notifications | APNs |

## Data Flows

### Flow 1: Camera Roll Upload

```
User → iOS PhotosPicker → Extract Audio → Upload Audio to Backend
                                              ↓
                              Backend: Whisper API → Transcript
                                              ↓
                              Backend: Claude API → Summaries + Tags
                                              ↓
                              Backend: Store in PostgreSQL
                                              ↓
                              Backend: Delete audio file
                                              ↓
                              iOS: Fetch & cache summaries
```

### Flow 2: URL Paste (TikTok/IG)

```
User → Paste URL → iOS validates URL format
                      ↓
        iOS: Download video to temp (yt-dlp or platform SDK)
                      ↓
        iOS: On-device transcription (WhisperKit / Speech)
                      ↓
        iOS: Upload transcript text only to backend
                      ↓
        Backend: Claude API → Summaries + Tags
                      ↓
        Backend: Store in PostgreSQL (no video)
                      ↓
        iOS: Fetch & cache summaries
```

### Flow 3: URL Paste (YouTube)

```
User → Paste URL → iOS sends URL to backend
                      ↓
        Backend: YouTube Data API → Get captions
                      ↓
        Backend: Claude API → Summaries + Tags
                      ↓
        Backend: Store in PostgreSQL
                      ↓
        iOS: Fetch & cache summaries
```

### Flow 4: Habit Creation

```
User → Taps "Make action points" on video summary
                      ↓
        iOS: Sends request to backend with video_id
                      ↓
        Backend: Claude API → Suggest 1-3 habits
                      ↓
        iOS: User selects habits, sets frequency/reminder time
                      ↓
        iOS: Schedules local notifications (UNUserNotificationCenter)
                      ↓
        iOS: Saves habit to local SwiftData + syncs to backend
```

### Flow 5: Subscription Verification

```
RevenueCat → Webhook to backend on purchase/renewal/cancel
                      ↓
        Backend: Update user.subscription_tier in PostgreSQL
                      ↓
        iOS: Polls user profile or receives push
                      ↓
        iOS: Unlocks/locks features based on tier
```

## Database Schema (PostgreSQL)

```sql
-- Users
users (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE,
  apple_id TEXT UNIQUE,
  password_hash TEXT,
  subscription_tier TEXT DEFAULT 'free',
  subscription_expires_at TIMESTAMP,
  created_at TIMESTAMP
)

-- Playbooks (user-created categories)
playbooks (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users,
  name TEXT,
  icon TEXT,
  created_at TIMESTAMP
)

-- Videos (saved content)
videos (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users,
  playbook_id UUID REFERENCES playbooks,
  source_url TEXT,
  source_platform TEXT, -- 'tiktok', 'instagram', 'youtube', 'camera_roll'
  creator_handle TEXT,
  title TEXT,
  thumbnail_url TEXT,
  transcript TEXT,
  summary_bullets JSONB,
  summary_steps JSONB, -- [{step, timestamp}, ...]
  summary_cards JSONB, -- [{front, back}, ...]
  tags TEXT[],
  video_file_url TEXT, -- Only for camera roll uploads
  created_at TIMESTAMP
)

-- Habits (extracted from videos)
habits (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users,
  video_id UUID REFERENCES videos,
  title TEXT,
  frequency TEXT, -- 'daily', '3x_weekly', 'weekly'
  reminder_time TIME,
  reminder_days INTEGER[], -- [0,1,2,3,4,5,6] for days of week
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  created_at TIMESTAMP
)

-- Habit completions
habit_completions (
  id UUID PRIMARY KEY,
  habit_id UUID REFERENCES habits,
  completed_at TIMESTAMP,
  user_timezone TEXT
)

-- Monthly usage tracking
usage_tracking (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users,
  month DATE, -- First of month
  videos_processed INTEGER DEFAULT 0
)
```

## Build Order (Phase Dependencies)

```
Phase 1: Foundation
├── FastAPI project setup
├── PostgreSQL schema + migrations
├── Basic auth (email/password)
└── iOS project setup + SwiftData models

Phase 2: Authentication
├── Apple Sign In (backend + iOS)
├── JWT token management
└── User profile sync

Phase 3: Video Capture (iOS)
├── Camera roll upload
├── Share extension
├── URL paste + validation
└── On-device transcription (WhisperKit)

Phase 4: Backend Processing
├── Whisper API integration
├── Claude API integration
├── Summary generation prompts
├── Tag generation
└── YouTube captions API

Phase 5: Playbooks & Organization
├── Playbook CRUD
├── Video listing by Playbook
├── Tag editing
├── Search (full-text)

Phase 6: Summary Display (iOS)
├── Bullet view
├── Step-by-step view with timestamps
├── Card swipe view
├── Deep-link to source

Phase 7: Habit System
├── Habit extraction (Claude prompt)
├── Habit CRUD
├── Local notifications
├── Streak tracking
├── Progress per Playbook

Phase 8: Subscriptions
├── RevenueCat integration (iOS)
├── Webhook handler (backend)
├── Feature gating (free vs Pro)
├── Usage limits

Phase 9: Pro Features
├── Weekly synthesis (Claude digest)
├── Email delivery
├── All summary formats unlocked

Phase 10: Polish & Launch
├── Onboarding flow
├── Error handling
├── Analytics
├── App Store assets
└── Marketing site
```

## Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **On-device transcription for TikTok/IG** | Privacy (no video leaves device), legal safety (no video storage) |
| **Transcript-only storage for URLs** | Cost efficiency, legal safety, lean architecture |
| **SwiftData for local cache** | Native iOS 17+, seamless SwiftUI integration, handles offline gracefully |
| **Async SQLAlchemy** | Non-blocking DB ops critical when LLM API calls are slow |
| **RevenueCat over raw StoreKit** | Abstracts StoreKit 1/2, handles receipts, analytics included |
| **Local notifications over backend push** | Simpler for habit reminders, works offline |
| **App Group for Share Extension** | Share extension needs access to same SwiftData store |
