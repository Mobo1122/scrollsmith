# Features Research: Scrollsmith

**Researched:** 2026-01-18
**Domain:** Video-saving + AI summarization + ADHD-friendly habit tracking

## Feature Categories

### Table Stakes (Must Have)

These are expected by users—missing any causes abandonment.

| Feature | Complexity | Notes |
|---------|------------|-------|
| **Video Capture** | | |
| Share sheet extension | Medium | iOS share sheet integration for TikTok/IG/YouTube |
| Camera roll upload | Low | PhotosPicker in SwiftUI |
| URL paste | Medium | Parse and validate video URLs |
| **Organization** | | |
| Playbooks/Collections | Low | User-created categories (Business, Fitness, etc.) |
| Tags | Low | Auto-generated + editable |
| Search | Medium | Full-text search across transcripts/titles |
| **Summaries** | | |
| Bullet points summary | Low | LLM-generated key takeaways |
| Original source link | Low | Deep-link back to platform |
| Thumbnail/preview | Low | Store or generate from video |
| **Authentication** | | |
| Apple Sign In | Medium | Required for App Store if offering social login |
| Email/password | Medium | Fallback auth option |
| **Subscription** | | |
| Freemium model | Medium | Clear free vs Pro distinction |
| Restore purchases | Low | RevenueCat handles this |

### Differentiators (Competitive Advantage)

These set Scrollsmith apart from Pocket, Readwise, and standard habit apps.

| Feature | Complexity | Value | Notes |
|---------|------------|-------|-------|
| **AI Summarization** | | | |
| Step-by-step checklist w/ timestamps | Medium | High | Unique for video content |
| Swipeable cards format | Medium | High | ADHD-friendly bite-sized consumption |
| Auto-tagging | Low | Medium | LLM suggests tags from content |
| **Habit Extraction** | | | |
| "Make action points" from video | High | Very High | Core differentiator—video to habit pipeline |
| Frequency selection (daily/3x/weekly) | Low | High | Simple scheduling |
| Push notification reminders | Medium | High | Quick completion from notification |
| Streak tracking | Low | High | Motivation without punishment |
| Progress per Playbook | Medium | Medium | Visual progress by category |
| **Weekly Synthesis** | | | |
| LLM digest email | Medium | High | Pro feature—patterns across saved content |
| **ADHD-Specific UX** | | | |
| Minimal friction capture | Low | Very High | One-tap save via share sheet |
| Visual progress indicators | Low | High | Dopamine from visible progress |
| Limit to 1-3 habits per video | Low | High | Prevents overwhelm |
| Streak forgiveness | Low | High | Miss one day ≠ lose everything |

### Dependencies Between Features

```
Camera Roll Upload → Server Transcription → Summaries → Habits
                                    ↓
URL Paste → On-Device Transcription → Summaries → Habits
                                    ↓
Share Sheet → (either path above) → Summaries → Habits

Playbooks ← Tags ← Summaries
              ↑
         Search indexes

Subscriptions → Unlocks: All formats, Habit mode, Weekly synthesis
```

### Anti-Features (Do NOT Build)

| Feature | Reason |
|---------|--------|
| Social sharing / following | Scope creep; single-user focus for v1 |
| Collaborative Playbooks | Multi-user complexity; defer to v2+ |
| In-app video editing | Not core value; users want to consume, not edit |
| Comments / community | Not core value; this is personal organization |
| Gamification with penalties | ADHD users respond poorly to punishment mechanics |
| Character damage / financial stakes | Increases anxiety, reduces adoption |
| Unlimited habit tracking | Research shows 1-3 habits max is effective |
| Complex data entry | Leads to "tracking theater"—more logging than doing |
| AI chatbot interface | Distraction from core loop; summaries are sufficient |
| Video downloading from URLs | Legal issues, storage costs—use transcripts only |
| Offline video playback | Not storing videos; deep-link to platforms instead |

## Competitive Landscape

### Video/Content Curation Apps

| App | Strengths | Weaknesses for Scrollsmith Users |
|-----|-----------|----------------------------------|
| **Pocket** | Shutting down July 2025 | N/A—users need alternative |
| **Readwise Reader** | Best-in-class highlights, YouTube transcripts | $9/month, no habit extraction, article-focused |
| **Raindrop.io** | Visual organization, free tier | No AI summaries, no habits |
| **Matter** | Audio narration, highlights | No video focus, no habits |

### Habit Tracking Apps

| App | Strengths | Weaknesses for Scrollsmith Users |
|-----|-----------|----------------------------------|
| **Streaks** | Beautiful iOS design, 12-habit limit | No content source, just habits |
| **Habitica** | Gamification, fun | Can feel punishing, no video integration |
| **Focus Bear** | ADHD-designed | No video capture/summarization |
| **Lunatask** | Priority sorting | Complex interface |

### Gap Scrollsmith Fills

**No app currently connects:**
- Video capture/curation
- AI summarization with multiple formats
- Habit extraction from content
- ADHD-friendly UX patterns

This is Scrollsmith's unique position.

## ADHD-Specific Design Principles

Based on research into ADHD app best practices:

1. **Reduce friction** — One-tap capture, minimal configuration
2. **Limit choices** — 1-3 habits per video, not unlimited
3. **Visual progress** — Streaks, progress bars, completion indicators
4. **Forgiveness** — Missing one day doesn't break streak entirely
5. **No punishment** — Avoid character damage, financial penalties, shame mechanics
6. **External accountability** — Push notifications as gentle nudges
7. **Immediate feedback** — Satisfying completion animations
8. **Start small** — Encourage starting with one Playbook, one habit

## Sources

- [Best ADHD Apps 2025 - AuDHD Psychiatry](https://www.audhdpsychiatry.co.uk/best-adhd-apps/)
- [Focus Bear - ADHD Habit Tracker](https://www.focusbear.io/blog-post/focus-bear-habit-tracker-designed-for-people-with-adhd)
- [Top Habit Tracker Apps 2025 - Moore Momentum](https://mooremomentum.com/blog/top-habit-tracker-apps/)
- [Reclaim Habit Tracker Apps](https://reclaim.ai/blog/habit-tracker-apps)
- [Pocket Alternatives 2025 - CollectRead](https://collectread.com/blog/best-pocket-alternatives/)
- [Pocket Shutdown - 9to5Mac](https://9to5mac.com/2025/05/28/pocket-read-it-later-alternatives/)
- [Best Bookmarking Apps - Zapier](https://zapier.com/blog/best-bookmaking-read-it-later-app/)
