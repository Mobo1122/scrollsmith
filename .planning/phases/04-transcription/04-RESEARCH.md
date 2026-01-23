# Phase 4: Transcription Research

## Architecture Decisions

### Transcription Paths

| Video Source | Flow |
|-------------|------|
| **TikTok/Instagram** | iOS downloads media → iOS extracts audio → iOS transcribes (WhisperKit) → Backend receives transcript text only |
| **Camera Roll** | iOS extracts audio → iOS transcribes (WhisperKit) → Backend receives transcript text only |
| **YouTube** | Backend fetches API captions (free) → iOS receives transcript (fallback: iOS downloads + transcribes) |

### Key Design Decisions

1. **All transcription on-device** - WhisperKit (iOS 17+) or Speech Framework fallback
2. **iOS downloads TikTok/IG media** - Using WKWebView for URL extraction
3. **Backend only stores transcripts** - No video/audio file handling
4. **YouTube API for captions** - Free and instant when available
5. **Model download on first transcription** - Not during onboarding

## Technology Choices

### WhisperKit
- **Package**: https://github.com/argmaxinc/WhisperKit
- **Minimum iOS**: 17.0
- **Model sizes**: tiny (~75MB), base (~150MB)
- **Accuracy**: Excellent for English, good for other languages
- **Speed**: Real-time to 2x on modern devices

### Speech Framework (Fallback)
- **Minimum iOS**: 10.0 (on-device: iOS 13+)
- **Accuracy**: Good for clear speech, poor for accents/noise
- **Limitations**: 1-minute audio limit per request

### youtube-transcript-api
- **No API key required** - Uses YouTube's internal transcript API
- **Languages**: Auto-selects best available
- **Rate limits**: None observed in normal use

## Implementation Files

### iOS Services Created
- `MediaDownloadService.swift` - Downloads video from TikTok/Instagram
- `AudioExtractor.swift` - Extracts audio using AVFoundation
- `WhisperKitService.swift` - On-device transcription (iOS 17+)
- `SpeechTranscriptionService.swift` - Fallback transcription
- `TranscriptionOrchestrator.swift` - Routes videos through pipelines

### iOS Modified
- `PendingUpload.swift` - Added transcription status fields
- `APIClient.swift` - Added video endpoints
- `UploadQueueService.swift` - Integrated orchestrator

### Backend Created
- `youtube_captions.py` - YouTube caption fetching
- `video.py` (schemas) - Request/response models
- `videos.py` (endpoints) - Video API endpoints

### Backend Modified
- `config.py` - Added YOUTUBE_API_KEY
- `__init__.py` - Included videos router
- `requirements.txt` - Added google-api-python-client, youtube-transcript-api

## TikTok/Instagram Download Approach

The MediaDownloadService uses a two-phase extraction strategy:

1. **HTML Parsing** (fast path)
   - Fetch page with mobile User-Agent
   - Search for video URLs in:
     - `og:video` meta tags
     - `playAddr` / `downloadAddr` in JSON
     - `video_url` in page data

2. **WebView Extraction** (fallback)
   - Load page in hidden WKWebView
   - Wait for JS to render
   - Extract `<video>` element sources

## Environment Variables

```
YOUTUBE_API_KEY=AIza...  # Optional, for video titles only
```

## Manual Xcode Setup Required

1. Add WhisperKit via SPM: `https://github.com/argmaxinc/WhisperKit`
2. Add to Info.plist:
   ```xml
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>Scrollsmith uses speech recognition to transcribe videos on your device for privacy.</string>
   ```
