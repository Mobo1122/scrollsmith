# Phase 1 Research: Foundation

**Researched:** 2026-01-18

## Overview

Foundation phase establishes the core infrastructure: FastAPI backend with async PostgreSQL on Railway, and SwiftUI iOS app with SwiftData for local persistence.

## Backend: FastAPI + Async SQLAlchemy + PostgreSQL

### Project Structure (2025-2026 Best Practices)

**Recommended structure:**
```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py           # FastAPI app entry
│   ├── api/
│   │   ├── __init__.py
│   │   ├── deps.py       # Dependency injection (DB sessions)
│   │   └── v1/
│   │       ├── __init__.py
│   │       └── endpoints/
│   │           └── health.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py     # Pydantic settings
│   │   └── database.py   # Async engine + session
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── video.py
│   │   ├── habit.py
│   │   └── playbook.py
│   └── schemas/          # Pydantic models
├── alembic/
│   ├── versions/
│   └── env.py           # Async config
├── alembic.ini
├── requirements.txt
└── Dockerfile (optional)
```

**Key dependencies (2025-2026):**
```
fastapi[standard]>=0.115.0
uvicorn[standard]>=0.31.0
sqlalchemy[asyncio]>=2.0.0
asyncpg<0.30.0
alembic>=1.13.0
pydantic>=2.0.0
pydantic-settings>=2.0.0
python-dotenv>=1.0.0
```

### Async SQLAlchemy 2.0 Setup

**Database connection:**
- Use `postgresql+asyncpg://` connection string
- Configure with `create_async_engine` and `async_sessionmaker`
- Set pool_size=5, max_overflow=10 for production
- Use dependency injection for sessions

**Important:** Pin `asyncpg<0.30.0` if encountering issues.

### Alembic Async Migrations

**Initialize with async template:**
```bash
alembic init -t async alembic
```

**Key configuration:**
- Import all models in `alembic/env.py` for autogenerate
- Use `async_engine_from_config` for async migrations
- Run migrations before server starts in production

**Workflow:**
1. `alembic revision --autogenerate -m "message"`
2. Review generated migration
3. `alembic upgrade head`

### Railway Deployment

**Features:**
- Automatic PostgreSQL provisioning
- Built-in environment variable management (DATABASE_URL auto-injected)
- Automatic HTTPS
- GitHub integration for CI/CD

**Start command:**
```bash
alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

## iOS: SwiftUI + SwiftData

### Project Setup (iOS 17+)

**Requirements:**
- Xcode 15+
- iOS 17.0+ deployment target
- SwiftUI app lifecycle

**SwiftData setup:**
- Use `@Model` macro on model classes
- Add `.modelContainer(for: [Model.self])` to WindowGroup
- Access with `@Environment(\.modelContext)` and `@Query`

### URLSession Async Networking

**Modern approach:**
```swift
let (data, response) = try await URLSession.shared.data(from: url)
```

- Use `async/await` (not completion handlers)
- Always wrap in try-catch
- Check HTTP status codes
- Use `actor` for thread-safe API clients

## Schema Design for Foundation

**Phase 1 minimal schema:**
- users (id, email, password_hash, apple_id, subscription_tier)
- playbooks (id, user_id, name, icon)
- videos (id, user_id, playbook_id, source_url, transcript, summary_bullets, tags)
- habits (id, user_id, video_id, title, frequency, current_streak)

**Indexes:**
- user_id on videos, habits, playbooks
- playbook_id on videos

## Common Pitfalls

**Backend:**
1. Mixing sync/async database drivers
2. Missing model imports in alembic env.py
3. Not using `-t async` for alembic init
4. Hardcoding secrets instead of environment variables
5. Connection pool exhaustion (configure pool_size)

**iOS:**
1. Missing `.modelContainer()` setup
2. Using old completion-based networking
3. Not handling network errors
4. Missing iOS 17+ requirement check
5. UI updates from background threads (use `@MainActor`)

## Health Check Implementation

**Backend endpoint:**
```python
@router.get("/health")
async def health_check(db: AsyncSession = Depends(get_db)):
    await db.execute("SELECT 1")
    return {"status": "healthy", "database": "connected"}
```

**iOS test:**
```swift
let health: HealthResponse = try await client.get(endpoint: "/health")
assert(health.status == "healthy")
```

## Sources

- [FastAPI Best Practices](https://github.com/zhanymkanov/fastapi-best-practices)
- [Building Async APIs with FastAPI and SQLAlchemy 2.0](https://leapcell.io/blog/building-high-performance-async-apis-with-fastapi-sqlalchemy-2-0-and-asyncpg)
- [Setup FastAPI with Async SQLAlchemy 2, Alembic](https://berkkaraal.com/blog/2024/09/19/setup-fastapi-project-with-async-sqlalchemy-2-alembic-postgresql-and-docker/)
- [Railway FastAPI Deployment](https://docs.railway.com/guides/fastapi)
- [SwiftUI and SwiftData Guide](https://www.hackingwithswift.com/articles/263/build-your-first-app-with-swiftui-and-swiftdata)
- [Modern iOS Networking with async/await](https://dev.to/markkazakov/modern-networking-in-ios-with-urlsession-and-asyncawait-a-practical-guide-4o0o)
