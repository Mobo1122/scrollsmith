# Pitfalls Research: Scrollsmith

**Researched:** 2026-01-18
**Domain:** iOS video processing, AI integration, subscriptions, habit tracking

## Critical Pitfalls

### 1. Share Extension Memory Limits

**Problem:** iOS Share Extensions have strict memory limits (~120MB). Processing video or running on-device transcription can crash the extension.

**Warning Signs:**
- Extension crashes silently when sharing videos
- Works in simulator but fails on device
- Large videos fail while small ones succeed

**Prevention:**
- Don't process video in Share Extension—just save URL/metadata to App Group
- Let main app handle transcription in background
- Use `beginBackgroundTask` for extended processing

**Phase:** Phase 3 (Video Capture)

---

### 2. On-Device Whisper Model Size

**Problem:** WhisperKit models range from 40MB (tiny) to 1.5GB (large). App size balloons, and large models may not fit in memory on older devices.

**Warning Signs:**
- App Store rejection for excessive size
- Memory warnings on iPhone 12 and earlier
- Slow transcription causing user abandonment

**Prevention:**
- Ship with `tiny` or `base` model in app bundle (~40-150MB)
- Download larger models on-demand if user opts in
- Detect device capability and select appropriate model
- Offer server-side transcription as fallback

**Phase:** Phase 3 (Video Capture) + Phase 4 (Backend Processing)

---

### 3. LLM Cost Explosion

**Problem:** Claude API costs can spiral quickly if prompts are inefficient or transcripts are long. Each video = 1+ API call for summaries, potentially more for habits.

**Warning Signs:**
- Monthly API bill exceeds projections
- Long transcripts consuming excessive tokens
- Users on free tier consuming expensive API calls

**Prevention:**
- Truncate transcripts to ~4000 tokens before sending
- Cache summaries—never regenerate existing ones
- Use Claude 3.5 Haiku for simple tasks (tags), Sonnet for summaries
- Implement strict rate limits per user tier
- Track per-user API cost attribution

**Phase:** Phase 4 (Backend Processing)

---

### 4. YouTube API Quota Limits

**Problem:** YouTube Data API has daily quota limits (10,000 units default). Caption retrieval costs 50-200 units per video. Free tier users can exhaust quota quickly.

**Warning Signs:**
- 403 "quotaExceeded" errors
- YouTube videos stop working mid-day
- Uneven availability (works in morning, fails afternoon)

**Prevention:**
- Apply for higher quota via Google Cloud Console
- Cache captions aggressively (YouTube videos don't change)
- Rate limit YouTube imports per user
- Fall back to on-device transcription if quota exhausted

**Phase:** Phase 4 (Backend Processing)

---

### 5. RevenueCat Webhook Reliability

**Problem:** Subscription webhooks can be delayed, duplicated, or missing. Trusting client-side subscription state allows easy exploitation.

**Warning Signs:**
- Users claim Pro but backend shows free
- Subscription status out of sync between devices
- Refunds not reflected in app

**Prevention:**
- Always verify entitlements server-side via RevenueCat API
- Use webhook as optimization, not source of truth
- Implement retry logic for webhook processing
- Log all subscription events for debugging

**Phase:** Phase 8 (Subscriptions)

---

### 6. Habit Reminder Notification Limits

**Problem:** iOS limits local notifications. Users can disable notifications, or notifications can be throttled by system.

**Warning Signs:**
- Users complain reminders don't arrive
- Reminders work initially, then stop
- Inconsistent behavior across iOS versions

**Prevention:**
- Request notification permission with clear value proposition
- Check notification authorization on app launch
- Implement in-app reminder UI as backup
- Consider optional server-side push for critical reminders

**Phase:** Phase 7 (Habit System)

---

### 7. Timezone and Streak Logic

**Problem:** Streak calculation across timezones is notoriously tricky. User travels, streak logic breaks.

**Warning Signs:**
- Users lose streaks when traveling
- Midnight edge cases cause incorrect calculations
- Complaints about "unfair" streak resets

**Prevention:**
- Store completions with user's local timezone at time of completion
- Calculate streaks relative to user's current timezone
- Implement "streak freeze" or grace period (miss 1 day, don't lose streak)
- Consider 48-hour window instead of strict 24-hour for daily habits

**Phase:** Phase 7 (Habit System)

---

### 8. SwiftData + Share Extension Sync

**Problem:** Share Extension and Main App can have concurrent access to SwiftData store, causing corruption or conflicts.

**Warning Signs:**
- Data appears in share extension but not main app
- Crashes when launching app after sharing
- Duplicate entries

**Prevention:**
- Use App Group container for shared SwiftData store
- Implement proper ModelContainer configuration for App Groups
- Use lightweight "pending import" table for share extension
- Main app processes pending imports on launch

**Phase:** Phase 3 (Video Capture)

---

### 9. TikTok/Instagram URL Fragility

**Problem:** TikTok and Instagram URLs change format frequently. Deep-linking can break, video metadata extraction can fail.

**Warning Signs:**
- Share extension stops recognizing URLs
- Extracted URLs don't load in-app
- Platform updates break URL parsing

**Prevention:**
- Extract canonical URL patterns, not full URLs
- Store original shared URL alongside parsed URL
- Gracefully degrade if URL can't be parsed (still save, mark as "needs attention")
- Monitor platform changes in analytics

**Phase:** Phase 3 (Video Capture)

---

### 10. App Store Rejection: Missing Login Option

**Problem:** If offering Apple Sign In, App Store requires it to be equally prominent. Also, subscriptions require restore purchase functionality.

**Warning Signs:**
- App Store review rejection
- Rejection mentions guideline 4.8 (Sign in with Apple)

**Prevention:**
- Apple Sign In button must be same size/prominence as other login options
- Implement restore purchases in settings
- Include privacy policy and terms of service links

**Phase:** Phase 2 (Authentication) + Phase 8 (Subscriptions)

---

## Medium-Risk Pitfalls

### 11. Prompt Injection in Transcripts

**Problem:** User-generated or transcribed content could contain prompt injection attacks when sent to Claude.

**Prevention:**
- Wrap user content in clear delimiters
- Use system prompts to instruct Claude to ignore instructions in user content
- Sanitize transcripts before storage

**Phase:** Phase 4 (Backend Processing)

---

### 12. Large Transcript Search Performance

**Problem:** Full-text search across thousands of transcripts can become slow.

**Prevention:**
- Use PostgreSQL full-text search (tsvector/tsquery)
- Create GIN indexes on searchable fields
- Paginate search results
- Consider ElasticSearch if scale demands it (likely not for v1)

**Phase:** Phase 5 (Playbooks & Organization)

---

### 13. Audio Extraction from Video

**Problem:** Extracting audio from camera roll videos for transcription requires AVFoundation knowledge. Large videos can be slow.

**Prevention:**
- Use AVAssetReader with AudioMix to extract audio track
- Process in chunks for memory efficiency
- Show progress UI during extraction
- Compress to mono 16kHz for Whisper

**Phase:** Phase 3 (Video Capture)

---

### 14. Claude Response Format Inconsistency

**Problem:** LLM responses can vary in format despite structured prompts. JSON parsing can fail.

**Prevention:**
- Use Claude's JSON mode when available
- Validate response structure before processing
- Implement retry with stricter prompt if format fails
- Have fallback formatting on client if server response is malformed

**Phase:** Phase 4 (Backend Processing)

---

### 15. Background Processing Limits (iOS)

**Problem:** iOS aggressively terminates background tasks. Long transcriptions may not complete.

**Prevention:**
- Use BGProcessingTask for long operations
- Request "Background processing" capability in Xcode
- Chunk work into resumable segments
- Notify user if processing will continue later

**Phase:** Phase 3 (Video Capture)

---

## Phase Mapping Summary

| Phase | Critical Pitfalls | Medium Pitfalls |
|-------|-------------------|-----------------|
| 2 - Auth | #10 App Store Rejection | - |
| 3 - Video Capture | #1 Share Extension Memory, #2 Model Size, #8 SwiftData Sync, #9 URL Fragility | #13 Audio Extraction, #15 Background Processing |
| 4 - Backend Processing | #3 LLM Cost, #4 YouTube Quota | #11 Prompt Injection, #14 Response Format |
| 5 - Organization | - | #12 Search Performance |
| 7 - Habit System | #6 Notification Limits, #7 Timezone/Streak | - |
| 8 - Subscriptions | #5 Webhook Reliability, #10 App Store Rejection | - |
