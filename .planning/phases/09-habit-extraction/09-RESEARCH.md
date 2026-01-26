# Phase 9: Habit Extraction - Research

**Researched:** 2026-01-26
**Domain:** Claude API prompt engineering, iOS multi-select UI, habit data modeling
**Confidence:** HIGH

## Summary

Phase 9 implements habit extraction from video transcripts using Claude API, enabling Pro users to convert video insights into trackable recurring habits. The feature requires a backend service for habit extraction (Claude Sonnet), API endpoints for habit management, and iOS UI for displaying suggestions with multi-select and frequency configuration.

The existing codebase already has a solid foundation: the `habits` table exists in the database, the `Habit` model is defined in both backend (SQLAlchemy) and iOS (SwiftData), and the summarization service provides a proven pattern for Claude API integration with retry logic. This phase primarily needs to add a new extraction service, API endpoints, and iOS UI components.

**Primary recommendation:** Follow the established summarization service pattern for habit extraction, use Claude Sonnet with structured outputs (output_format with json_schema), and implement iOS selection UI using SwiftUI List with checkmarks rather than edit mode multi-select for better UX.

## Standard Stack

The established libraries/tools for this domain:

### Core (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| anthropic (AsyncAnthropic) | latest | Claude API client | Already used for summarization |
| tenacity | latest | Retry logic with exponential backoff | Already used in summarization service |
| pydantic | v2 | Structured output schemas | Already used for summary schemas |
| SwiftUI | iOS 17+ | iOS UI framework | Project standard |
| SwiftData | iOS 17+ | Local persistence | Project standard |

### Supporting (No New Dependencies Needed)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| anthropic beta.messages | structured-outputs-2025-11-13 | Guaranteed JSON schema compliance | Use for habit extraction to ensure valid response structure |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Structured outputs beta | Prompt-only JSON | Structured outputs guarantee valid JSON, no parsing errors |
| Custom parsing | Pydantic validation | Pydantic already used, maintains consistency |
| Edit mode multi-select | Checkmark toggles | Checkmarks are more intuitive for "select which to create" UX |

**Installation:**
No new dependencies required. All libraries already in project.

## Architecture Patterns

### Recommended Project Structure
```
backend/
├── app/
│   ├── services/
│   │   └── habit_extraction.py    # NEW: Claude habit extraction service
│   ├── schemas/
│   │   └── habit.py               # NEW: Pydantic schemas for habits
│   └── api/v1/endpoints/
│       └── habits.py              # NEW: Habit API endpoints

ios/Scrollsmith/
├── Models/
│   └── HabitModels.swift          # NEW: HabitSuggestion, HabitFrequency types
├── Services/
│   └── APIClient.swift            # ADD: extractHabits(), createHabit() methods
├── ViewModels/
│   └── HabitExtractionViewModel.swift  # NEW: Manages extraction flow
└── Views/
    └── Habits/
        ├── HabitExtractionSheet.swift   # NEW: Suggestion list with selection
        └── FrequencyPickerView.swift    # NEW: Daily/3xWeekly/Weekly picker
```

### Pattern 1: Claude Structured Outputs for Extraction
**What:** Use Claude API's structured outputs beta feature to guarantee valid JSON response
**When to use:** When extracting structured data that must conform to a schema
**Example:**
```python
# Source: https://platform.claude.com/docs/en/build-with-claude/structured-outputs
from pydantic import BaseModel, Field
from typing import List

class HabitSuggestion(BaseModel):
    """A single habit suggestion extracted from video content."""
    title: str = Field(min_length=5, max_length=100, description="Short, actionable habit title")
    description: str = Field(max_length=300, description="Why this habit matters based on video content")
    suggested_frequency: str = Field(description="Suggested frequency: 'daily', '3x_weekly', or 'weekly'")

class HabitExtractionResponse(BaseModel):
    """Response from habit extraction."""
    habits: List[HabitSuggestion] = Field(min_length=1, max_length=3, description="1-3 concrete habit suggestions")

# API call with structured outputs
response = await client.beta.messages.create(
    model="claude-sonnet-4-5-20250514",
    max_tokens=1024,
    betas=["structured-outputs-2025-11-13"],
    system=HABIT_EXTRACTION_SYSTEM_PROMPT,
    messages=[{"role": "user", "content": f"Extract habits from this transcript:\n\n{transcript}"}],
    output_format={
        "type": "json_schema",
        "schema": HabitExtractionResponse.model_json_schema()
    }
)
```

### Pattern 2: Backend Tier Gating (Server-Side Security)
**What:** Check subscription tier on backend before allowing habit extraction
**When to use:** For Pro-only features where security matters
**Example:**
```python
# Source: Existing pattern in videos.py (line 432-442)
@router.post("/{video_id}/extract-habits", response_model=HabitExtractionResponse)
async def extract_habits(
    video_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Pro tier gate - server-side for security
    if current_user.subscription_tier != "pro":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "pro_required",
                "message": "Habit extraction requires Pro subscription",
                "upgrade_url": "/subscribe/pro"
            }
        )
    # ... proceed with extraction
```

### Pattern 3: iOS Selection Interface with Checkmarks
**What:** Custom List with toggle selection rather than edit-mode multi-select
**When to use:** When users need to select items AND configure each item (frequency)
**Example:**
```swift
// Source: SwiftUI best practices for iOS 17+
struct HabitSuggestionRow: View {
    let suggestion: HabitSuggestion
    @Binding var isSelected: Bool
    @Binding var selectedFrequency: HabitFrequency

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    isSelected.toggle()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }

                Text(suggestion.title)
                    .font(.headline)
            }

            if isSelected {
                Picker("Frequency", selection: $selectedFrequency) {
                    ForEach(HabitFrequency.allCases, id: \.self) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
```

### Anti-Patterns to Avoid
- **Client-side only tier checking:** Always verify Pro status on backend; iOS can be bypassed
- **Free-form LLM output parsing:** Use structured outputs to guarantee schema compliance
- **Edit mode for selection:** SwiftUI edit mode is for delete/reorder, not "select to create"
- **Storing frequency as free-form string:** Use enum values for consistency

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON extraction from LLM | Regex parsing + retry | Claude structured outputs beta | Guaranteed valid JSON, no parsing errors |
| Retry logic for API calls | Custom retry loop | tenacity (already in project) | Handles backoff, jitter, retries correctly |
| Tier gating logic | Duplicate checks in each endpoint | Extract to dependency (existing pattern) | DRY, consistent error format |
| Frequency picker UI | Custom buttons | SwiftUI Picker with .segmented style | Native look, accessibility built-in |

**Key insight:** The summarization service already solved Claude API integration patterns. Habit extraction is structurally identical - same retry logic, same error handling, different prompt and schema.

## Common Pitfalls

### Pitfall 1: Vague or Generic Habit Suggestions
**What goes wrong:** Claude generates habits like "exercise more" or "be mindful" instead of specific, actionable habits
**Why it happens:** System prompt doesn't constrain output to concrete, recurring actions
**How to avoid:** Include explicit constraints in prompt:
```
Generate habits that are:
- Specific and concrete (e.g., "Do 10 pushups" not "exercise")
- Recurring and trackable (can be done daily/weekly)
- Directly derived from video content (not generic advice)
- Phrased as actions, not goals (e.g., "Read for 15 minutes" not "Read more books")
```
**Warning signs:** Habits that could apply to any video, habits without clear completion criteria

### Pitfall 2: Pro Gate Only on iOS
**What goes wrong:** Free users can bypass iOS paywall and call API directly
**Why it happens:** Developers implement gate only in UI layer
**How to avoid:** Always check `current_user.subscription_tier` on backend. iOS check is UX optimization only.
**Warning signs:** API returns habits without checking tier

### Pitfall 3: Hardcoded Frequency Values
**What goes wrong:** Frequency stored as arbitrary strings, leading to inconsistent data
**Why it happens:** Using String instead of enum/constrained values
**How to avoid:** Define frequency enum on both backend and iOS:
```python
# Backend - Pydantic
suggested_frequency: Literal["daily", "3x_weekly", "weekly"]

# iOS - Swift enum
enum HabitFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case threeTimesWeekly = "3x_weekly"
    case weekly = "weekly"
}
```
**Warning signs:** Frequency values like "every day", "3 times a week" (inconsistent)

### Pitfall 4: Creating Habits Without User Confirmation
**What goes wrong:** All extracted habits created automatically without user selection
**Why it happens:** Skipping the selection step for "simplicity"
**How to avoid:** Always present suggestions, let user select which to create
**Warning signs:** API endpoint creates habits directly instead of returning suggestions

### Pitfall 5: Missing Transcript Validation
**What goes wrong:** Habit extraction attempted on videos without transcripts or with very short transcripts
**Why it happens:** Not checking transcript existence/quality before calling Claude
**How to avoid:** Validate transcript exists and meets minimum length (same as summarization)
**Warning signs:** API errors from Claude about insufficient content

## Code Examples

Verified patterns from official sources and existing codebase:

### Habit Extraction System Prompt
```python
# Source: Claude best practices + existing summarization patterns
HABIT_EXTRACTION_SYSTEM_PROMPT = """You are a habit extraction assistant. Your task is to identify 1-3 concrete, recurring habits from video transcripts.

Extract habits that are:
1. SPECIFIC: Concrete actions with clear completion criteria (e.g., "Do 20 pushups" not "exercise more")
2. RECURRING: Can be done daily, 3 times weekly, or weekly as a sustainable practice
3. DERIVED: Directly based on advice/techniques from the video content
4. ACTIONABLE: Phrased as verbs (e.g., "Write 3 gratitude items" not "Practice gratitude")

For each habit:
- title: Short, action-oriented title (5-100 chars)
- description: Brief explanation of why this habit matters, referencing the video content
- suggested_frequency: One of "daily", "3x_weekly", or "weekly" based on what makes sense

If the video doesn't contain actionable recurring advice, return fewer habits (minimum 1).
Never return generic self-help habits that aren't derived from the specific video content."""
```

### iOS Frequency Enum
```swift
// Source: Existing project enum patterns (SummaryModels.swift)
enum HabitFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case threeTimesWeekly = "3x_weekly"
    case weekly = "weekly"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .threeTimesWeekly: return "3x Weekly"
        case .weekly: return "Weekly"
        }
    }

    var timesPerWeek: Int {
        switch self {
        case .daily: return 7
        case .threeTimesWeekly: return 3
        case .weekly: return 1
        }
    }
}
```

### API Endpoint Pattern
```python
# Source: Existing videos.py endpoint patterns
@router.post("/{video_id}/extract-habits", response_model=HabitExtractionResponse)
async def extract_habits(
    video_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> HabitExtractionResponse:
    """Extract habit suggestions from a video transcript (Pro only).

    Returns 1-3 habit suggestions that user can select from.
    Does NOT create habits - use POST /habits to create selected habits.
    """
    # Pro tier gate
    if current_user.subscription_tier != "pro":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": "pro_required", "message": "Habit extraction requires Pro subscription"}
        )

    # Fetch video with transcript
    video = await get_video_or_404(video_id, current_user.id, db)

    if not video.transcript:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Video has no transcript"
        )

    # Extract habits
    suggestions = await habit_extraction_service.extract_habits(video.transcript)

    return HabitExtractionResponse(
        video_id=video.id,
        suggestions=suggestions
    )
```

### APIClient Method Pattern
```swift
// Source: Existing APIClient patterns
func extractHabits(videoId: UUID) async throws -> HabitExtractionResponse {
    guard let endpoint = URL(string: "\(baseURL)/api/v1/videos/\(videoId.uuidString.lowercased())/extract-habits") else {
        throw APIError.invalidURL
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"

    if let token = await getAccessToken() {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }

    // Handle Pro-required error specially
    if httpResponse.statusCode == 403 {
        throw APIError.proRequired
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        throw APIError.httpError(statusCode: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(HabitExtractionResponse.self, from: data)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Prompt-only JSON extraction | Structured outputs beta | Nov 2025 | Guaranteed valid JSON, no parsing errors |
| Manual retry loops | tenacity with exponential backoff | Already in project | Robust error handling |
| Edit mode multi-select | Custom toggle selection | iOS 16+ recommendation | Better UX for "select to create" flows |

**Deprecated/outdated:**
- Using `json_mode: true` without schema: Replaced by `output_format` with `json_schema` type
- Claude 3.x model strings: Project uses Claude 4.5 model strings (claude-sonnet-4-5-20250514)

## Open Questions

Things that couldn't be fully resolved:

1. **Habit Extraction Caching**
   - What we know: Summarization caches results in video.summary_* fields
   - What's unclear: Should habit suggestions be cached? User might want different habits on re-extraction
   - Recommendation: Don't cache suggestions. Always extract fresh. Created habits are persisted separately.

2. **Transcript Quality Threshold**
   - What we know: Summarization has minimum 50 word requirement
   - What's unclear: Should habit extraction have same or different threshold?
   - Recommendation: Use same 50 word minimum for consistency, but habits may need more content for quality suggestions

3. **Maximum Habits Per Video**
   - What we know: Current UI design shows 1-3 suggestions
   - What's unclear: Should there be a limit on total habits created from one video?
   - Recommendation: Start without limit, monitor for abuse patterns

## Sources

### Primary (HIGH confidence)
- Claude API Structured Outputs: https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- Claude 4 Best Practices: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices
- Existing codebase: backend/app/services/summarization.py (Claude API patterns)
- Existing codebase: backend/app/api/v1/endpoints/videos.py (tier gating patterns)
- Existing codebase: ios/Scrollsmith/Models/SummaryModels.swift (enum patterns)

### Secondary (MEDIUM confidence)
- SwiftUI List Selection: https://developer.apple.com/documentation/swiftui/list
- Hacking with Swift List Selection: https://www.hackingwithswift.com/books/ios-swiftui/letting-users-select-items-in-a-list

### Tertiary (LOW confidence)
- General habit tracking schema patterns (web search, multiple sources agreed)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project, patterns verified
- Architecture: HIGH - Follows existing summarization service pattern exactly
- Pitfalls: HIGH - Based on existing project patterns and Claude documentation
- Prompt design: MEDIUM - Based on Claude best practices, but prompt tuning may be needed

**Research date:** 2026-01-26
**Valid until:** 2026-02-26 (30 days - stable domain, Claude API patterns unlikely to change)
