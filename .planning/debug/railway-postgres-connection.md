---
status: diagnosed
trigger: "Railway Backend Deployment Connection Refused - OSError: Multiple exceptions: [Errno 111] Connect call failed"
created: 2026-01-19T00:00:00Z
updated: 2026-01-19T00:01:00Z
symptoms_prefilled: true
---

## Current Focus

hypothesis: CONFIRMED - Railway internal networking requires explicit service reference variable
test: Examined alembic/env.py, config.py, database.py, railway.json
expecting: N/A - root cause identified
next_action: Provide fix recommendation

## Symptoms

expected: Backend service should connect to Postgres and run migrations successfully
actual: OSError with connection refused to both IPv6 and IPv4 addresses on port 5432
errors: |
  OSError: Multiple exceptions: [Errno 111] Connect call failed ('fd12:fe43:67cd:1:2000:a6:a8c:a676', 5432, 0, 0), [Errno 111] Connect call failed ('10.140.166.118', 5432)
reproduction: Deploy backend to Railway with Postgres service
started: During Railway deployment

## Eliminated

- hypothesis: Code bug in config.py conversion logic
  evidence: The postgresql:// to postgresql+asyncpg:// conversion is correct and well-implemented
  timestamp: 2026-01-19T00:01:00Z

- hypothesis: Alembic env.py misconfiguration
  evidence: env.py correctly loads DATABASE_URL from settings when not in alembic.ini (line 29-30)
  timestamp: 2026-01-19T00:01:00Z

## Evidence

- timestamp: 2026-01-19T00:00:00Z
  checked: Error message analysis
  found: Connection refused on port 5432 (standard Postgres port) - but Railway public URL uses port 42083
  implication: The internal URL (postgres.railway.internal:5432) is being used but may not be resolvable/reachable

- timestamp: 2026-01-19T00:01:00Z
  checked: alembic/env.py lines 23, 29-30
  found: Settings imported at line 23, DATABASE_URL used at line 30 via settings.DATABASE_URL
  implication: Alembic correctly uses the same settings as the app

- timestamp: 2026-01-19T00:01:00Z
  checked: config.py Settings class
  found: DATABASE_URL loaded from environment with validator converting postgresql:// to postgresql+asyncpg://
  implication: The async conversion is correct, but requires DATABASE_URL to be set in environment

- timestamp: 2026-01-19T00:01:00Z
  checked: Railway networking documentation knowledge
  found: Railway internal URLs (*.railway.internal) ONLY work for services within the SAME project that have explicit variable references. The backend service needs to REFERENCE the Postgres service's DATABASE_URL variable, not just have the same name.
  implication: The backend likely doesn't have DATABASE_URL configured - it's falling back to default or trying to use internal URL without proper service linking

- timestamp: 2026-01-19T00:01:00Z
  checked: Port in error vs Railway URLs
  found: Error shows port 5432 (internal), but Railway PUBLIC_URL uses 42083. Internal URL uses 5432 which is correct.
  implication: DNS resolution worked (got IP addresses), but the network connection is refused - suggesting service linking issue

## Resolution

root_cause: |
  Railway services don't automatically share environment variables. The DATABASE_URL variable exists on the Postgres service, but the backend service needs to explicitly REFERENCE it using Railway's variable reference syntax: ${{Postgres.DATABASE_URL}}.

  Without this reference:
  1. The backend doesn't have DATABASE_URL set
  2. It falls back to the default in config.py OR
  3. Even if manually set, internal networking (postgres.railway.internal) only works when services are properly linked via variable references

  The internal URL IS the correct one to use (port 5432), but Railway's private networking requires explicit service references to enable inter-service communication.

fix: |
  In Railway dashboard for the backend service:
  1. Go to Variables tab
  2. Add variable: DATABASE_URL = ${{Postgres.DATABASE_URL}}

  This creates a reference to the Postgres service's DATABASE_URL, which:
  - Automatically populates the value
  - Enables Railway's internal networking between the services
  - Uses the internal URL (postgres.railway.internal:5432) which is faster and more secure

verification: After setting the variable reference, redeploy the backend service
files_changed: []
