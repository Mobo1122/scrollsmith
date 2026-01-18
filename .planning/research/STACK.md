# Stack Research: Scrollsmith

**Researched:** 2026-01-18
**Domain:** iOS video-saving + AI summarization + habit tracking

## Recommended Stack

### iOS Client (SwiftUI Native)

| Component | Recommendation | Version | Confidence |
|-----------|---------------|---------|------------|
| UI Framework | SwiftUI | iOS 17+ | ✅ High |
| Architecture | MVVM + Swift Concurrency | - | ✅ High |
| Networking | URLSession + async/await | Native | ✅ High |
| Local Storage | SwiftData | iOS 17+ | ✅ High |
| On-Device Transcription | WhisperKit (Argmax) | Latest | ✅ High |
| Fallback Transcription | Apple Speech Framework | iOS 17+ | ✅ High |
| Video Player | AVKit + AVFoundation | Native | ✅ High |
| Share Extension | App Extensions | Native | ✅ High |
| Subscriptions | RevenueCat SDK | 5.x | ✅ High |
| Auth | Apple Sign In + Custom | Native | ✅ High |
| Push Notifications | APNs + UNUserNotificationCenter | Native | ✅ High |
| Keychain | KeychainAccess | 4.x | ✅ High |

**WhisperKit Rationale:**
- Apple-optimized implementation of OpenAI's Whisper
- CoreML backend leverages Apple Neural Engine (ANE)
- Models: tiny, base, small (trade-off size vs accuracy)
- Works offline, privacy-preserving
- Swift Package Manager installation

**SwiftData Rationale:**
- Native Apple solution for iOS 17+
- Seamless SwiftUI integration with @Query
- Handles migrations, iCloud sync if needed later
- Replaces Core Data complexity

### Backend (Python/FastAPI)

| Component | Recommendation | Version | Confidence |
|-----------|---------------|---------|------------|
| Framework | FastAPI | 0.115+ | ✅ High |
| Database ORM | SQLAlchemy 2.0 (async) | 2.0+ | ✅ High |
| DB Driver | asyncpg | 0.29+ | ✅ High |
| Migrations | Alembic (async) | 1.13+ | ✅ High |
| LLM SDK | anthropic-sdk-python | Latest | ✅ High |
| Audio Transcription | OpenAI Whisper API | Latest | ✅ High |
| Task Queue | Celery + Redis | 5.x | ⚠️ Medium |
| File Storage | boto3 (S3) | Latest | ✅ High |
| Auth Tokens | python-jose (JWT) | Latest | ✅ High |
| Validation | Pydantic v2 | 2.x | ✅ High |
| HTTP Client | httpx (async) | Latest | ✅ High |

**Async SQLAlchemy Rationale:**
- First-class async support in 2.0
- asyncpg driver offers superior PostgreSQL performance
- Non-blocking database operations critical for LLM API latency
- FastAPI dependency injection handles session lifecycle

**Anthropic SDK Rationale:**
- Official SDK with full async support
- Handles streaming responses (SSE)
- Built-in retry logic, error handling
- Type definitions for all params/responses

### External Services

| Service | Provider | Purpose | Confidence |
|---------|----------|---------|------------|
| Transcription (server) | OpenAI Whisper API | Camera roll uploads | ✅ High |
| LLM Summarization | Anthropic Claude 3.5 Sonnet | Summaries, tags, habits | ✅ High |
| Object Storage | AWS S3 / Cloudflare R2 | Rare video storage | ✅ High |
| Subscriptions | RevenueCat | Apple IAP management | ✅ High |
| Hosting | Railway | FastAPI + PostgreSQL | ✅ High |
| Monitoring | Sentry | Error tracking | ⚠️ Medium |

### Database Schema Strategy

**PostgreSQL with:**
- JSONB columns for flexible summary formats
- Full-text search for transcript search
- UUID primary keys
- Timestamp columns with timezone

## What NOT to Use

| Technology | Reason |
|------------|--------|
| Core Data | SwiftData is the modern replacement for iOS 17+ |
| Realm | Unnecessary complexity when SwiftData works |
| Firebase | Custom backend provides more control for LLM integration |
| GraphQL | REST is simpler for this use case, FastAPI excels at it |
| MongoDB | Structured relational data (users, videos, habits) fits PostgreSQL better |
| Celery (maybe) | Consider FastAPI BackgroundTasks first; Celery only if queue persistence needed |
| whisper.cpp directly | WhisperKit wraps it with Apple optimizations |
| StoreKit 1 | RevenueCat abstracts StoreKit 1/2, but only StoreKit 2 for new projects |

## Version Compatibility Matrix

| iOS Version | On-Device Transcription | Features |
|-------------|------------------------|----------|
| iOS 17 | Apple Speech Framework | Base functionality |
| iOS 18+ | WhisperKit (Whisper) | Better accuracy, language support |

## Sources

- [WhisperKit by Argmax](https://github.com/argmaxinc/WhisperKit)
- [Building On-Device Speech-to-Text with Whisper + CoreML](https://medium.com/@jonataneduard/building-a-real-time-on-device-speech-to-text-in-swiftui-with-whisper-core-ml-ios-17-b1d468e44f4d)
- [FastAPI with Async SQLAlchemy 2.0](https://leapcell.io/blog/building-high-performance-async-apis-with-fastapi-sqlalchemy-2-0-and-asyncpg)
- [FastAPI Best Practices](https://github.com/zhanymkanov/fastapi-best-practices)
- [Anthropic Python SDK](https://github.com/anthropics/anthropic-sdk-python)
- [RevenueCat StoreKit 2 Tutorial](https://www.revenuecat.com/blog/engineering/ios-in-app-subscription-tutorial-with-storekit-2-and-swift/)
- [RevenueCat iOS Documentation](https://www.revenuecat.com/docs/getting-started/installation/ios)
