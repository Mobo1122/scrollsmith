# State: Scrollsmith

**Last Updated:** 2026-01-28

## Project Reference

See: [.planning/PROJECT.md](.planning/PROJECT.md) (updated 2026-01-28)

**Core value:** Turn video hoarding into action—users extract value from saved videos through AI summaries and convert insights into tracked habits

**Current focus:** v1 shipped — ready for next milestone

## Current Position

**Milestone:** v1 MVP ✅ SHIPPED
**Status:** Milestone complete, archived
**Last activity:** 2026-01-28 — v1 milestone complete

**Progress:** v1 complete (12 phases, 70 plans, 85 requirements)

## Milestone History

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v1 MVP | 1-12 | 70 | ✅ Complete | 2026-01-28 |

See [MILESTONES.md](MILESTONES.md) for details.

## Next Milestone

Not yet defined. Run `/gsd:new-milestone` to:
1. Define v2 focus (TikTok/IG support? Marketing site? etc.)
2. Gather requirements through questioning
3. Research implementation approaches
4. Create new ROADMAP.md and REQUIREMENTS.md

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
