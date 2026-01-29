# State: Scrollsmith

**Last Updated:** 2026-01-29

## Project Reference

See: [.planning/PROJECT.md](.planning/PROJECT.md) (updated 2026-01-29)

**Core value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits

**Current focus:** v1.1 UI Polish — Production-grade redesign inspired by Readwise Reader

## Current Position

**Milestone:** v1.1 UI Polish
**Status:** Defining requirements
**Last activity:** 2026-01-29 — Milestone v1.1 started

**Progress:** Requirements gathering

## Milestone History

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v1 MVP | 1-12 | 70 | ✅ Complete | 2026-01-28 |

See [MILESTONES.md](MILESTONES.md) for details.

## v1.1 Target Features

- Central video feed homepage (Inbox-style layout)
- Sidebar navigation: Library, Types, Playbooks, Tags, Trash
- Video cards with thumbnails, creator credits, duration
- Embedded YouTube player above summaries
- Fix: View Original / Create Action Points button overlap
- Fix: Steps/cards panel not functional for free tier

**Design inspiration:** Readwise Reader

## Pre-Launch Tasks (v1)

Before App Store submission:
- [ ] Create 5 App Store screenshots (1260×2736)
- [ ] Record 15-30s app preview video
- [ ] Upload materials to App Store Connect
- [ ] Final TestFlight testing
- [ ] Submit for App Review

## Infrastructure

| Component | URL/Location | Status |
|-----------|--------------|--------|
| Backend API | https://backend-production-d73a.up.railway.app | ✓ Live |
| PostgreSQL | Railway managed | ✓ Connected |
| iOS App | ios/Scrollsmith.xcodeproj | ✓ Building |

## Environment Variables (Railway)

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes* | OpenAI API key for Whisper transcription |
| `ASSEMBLYAI_API_KEY` | No | AssemblyAI API key (fallback transcription) |
| `ANTHROPIC_API_KEY` | Yes | Anthropic Claude API key for AI summarization |
| `SENTRY_DSN` | No | Sentry DSN for error monitoring |

*At least one transcription API key is required for camera roll uploads to work.

## Notes

- Mode: YOLO (auto-approve)
- Depth: Comprehensive
- Parallelization: Enabled
- No blockers

## Archives

v1 milestone archived to:
- [milestones/v1-ROADMAP.md](milestones/v1-ROADMAP.md) — Full phase details (12 phases, 70 plans)
- [milestones/v1-REQUIREMENTS.md](milestones/v1-REQUIREMENTS.md) — All 85 requirements
- [milestones/v1-MILESTONE-AUDIT.md](milestones/v1-MILESTONE-AUDIT.md) — Integration verification
