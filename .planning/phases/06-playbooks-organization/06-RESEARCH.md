# Phase 6: Playbooks & Organization - Research

**Researched:** 2026-01-23
**Domain:** CRUD operations, PostgreSQL full-text search, SwiftUI multi-select grids, SwiftData relationships
**Confidence:** HIGH

## Summary

Phase 6 requires implementing Playbook CRUD, many-to-many video-Playbook relationships, PostgreSQL full-text search with GIN indexes, and bulk operations. The key technical challenges are:

1. **Schema change**: Current schema has one-to-many (video -> playbook_id), but CONTEXT.md specifies many-to-many. This requires a migration with an association table.
2. **Full-text search**: PostgreSQL's tsvector + GIN index is the proven approach. Searching transcript + tags + summary_bullets requires weighted ranking (A for tags, B for summary, C for transcript).
3. **SwiftUI selection**: LazyVGrid has no built-in multi-select; must implement custom selection state management.
4. **SwiftData many-to-many**: Requires explicit `@Relationship(inverse:)` macro, with known iOS 17 bugs requiring default values.

**Primary recommendation:** Use PostgreSQL generated columns for tsvector, SQLAlchemy 2.0 bulk operations with `synchronize_session=False`, and a custom SwiftUI selection manager with debounced search.

## Standard Stack

### Backend (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SQLAlchemy | 2.0+ | ORM with async support | Already used, bulk operations via `execute(update/delete)` |
| Alembic | 1.13+ | Database migrations | Already used for schema versioning |
| FastAPI | 0.109+ | API endpoints | Already used |
| PostgreSQL | 15+ | Full-text search | Native tsvector, tsquery, GIN indexes |

### iOS (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI framework | Already used |
| SwiftData | iOS 17+ | Local persistence | Already used |
| Swift Concurrency | Built-in | Debounce, async operations | Already used |

### Supporting (No New Dependencies Needed)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PostgreSQL pg_trgm | Built-in | Fuzzy matching | Optional for typo tolerance |

**Installation:** No new dependencies required. All capabilities are built into existing stack.

## Architecture Patterns

### Database Schema Change: Many-to-Many

**Current schema (one-to-many):**
```
videos.playbook_id -> playbooks.id
```

**Required schema (many-to-many per CONTEXT.md):**
```sql
-- Association table
CREATE TABLE video_playbooks (
    video_id UUID REFERENCES videos(id) ON DELETE CASCADE,
    playbook_id UUID REFERENCES playbooks(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    PRIMARY KEY (video_id, playbook_id)
);
```

**SQLAlchemy 2.0 pattern:**
```python
# Source: SQLAlchemy 2.0 docs
from sqlalchemy import Table, Column, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

video_playbooks = Table(
    "video_playbooks",
    Base.metadata,
    Column("video_id", UUID(as_uuid=True), ForeignKey("videos.id", ondelete="CASCADE"), primary_key=True),
    Column("playbook_id", UUID(as_uuid=True), ForeignKey("playbooks.id", ondelete="CASCADE"), primary_key=True),
    Column("added_at", DateTime(timezone=True), server_default=func.now()),
)

class Video(Base):
    # ... existing fields ...
    playbooks: Mapped[List["Playbook"]] = relationship(
        "Playbook",
        secondary=video_playbooks,
        back_populates="videos",
    )

class Playbook(Base):
    # ... existing fields ...
    videos: Mapped[List["Video"]] = relationship(
        "Video",
        secondary=video_playbooks,
        back_populates="playbooks",
    )
```

### SwiftData Many-to-Many Pattern

**Important:** SwiftData has iOS 17.0 bugs with many-to-many based on alphabetical model name ordering.

```swift
// Source: hackingwithswift.com/quick-start/swiftdata/how-to-create-many-to-many-relationships
@Model
class Video {
    @Attribute(.unique) var id: UUID
    // ... other fields ...
    var playbooks: [Playbook] = []  // Default value required for iOS 17 bug
}

@Model
class Playbook {
    @Attribute(.unique) var id: UUID
    var name: String
    var isSystemFavorites: Bool = false  // For Favorites playbook
    // ... other fields ...

    @Relationship(inverse: \Video.playbooks)
    var videos: [Video] = []  // Default value required
}
```

**Critical:** Only specify `inverse:` on ONE side to avoid "Circular reference" errors.

### PostgreSQL Full-Text Search Pattern

**Recommended: Generated tsvector column with weighted fields**

```sql
-- Source: PostgreSQL docs textsearch-tables.html
ALTER TABLE videos
ADD COLUMN search_vector tsvector
GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(array_to_string(tags, ' '), '')), 'A') ||
    setweight(to_tsvector('english', coalesce(summary_bullets, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(transcript, '')), 'C')
) STORED;

CREATE INDEX idx_videos_search ON videos USING GIN (search_vector);
```

**Weight priority:** A (highest) = tags, B = summary_bullets, C = transcript

**Search query:**
```sql
SELECT id, ts_rank(search_vector, query) AS rank
FROM videos, plainto_tsquery('english', :search_term) query
WHERE user_id = :user_id
  AND search_vector @@ query
ORDER BY rank DESC
LIMIT 20;
```

### SQLAlchemy Async Bulk Operations

**Bulk delete pattern:**
```python
# Source: SQLAlchemy 2.0 docs orm/queryguide/dml.html
from sqlalchemy import delete

stmt = delete(Video).where(
    Video.id.in_(video_ids),
    Video.user_id == current_user.id
)
await session.execute(stmt, execution_options={"synchronize_session": False})
await session.commit()
```

**Bulk move (update association table):**
```python
# For many-to-many, manipulate association table directly
from sqlalchemy import insert, delete

# Remove from current playbooks
await session.execute(
    delete(video_playbooks).where(
        video_playbooks.c.video_id.in_(video_ids),
        video_playbooks.c.playbook_id == source_playbook_id
    )
)

# Add to target playbook
await session.execute(
    insert(video_playbooks),
    [{"video_id": vid, "playbook_id": target_playbook_id} for vid in video_ids]
)
await session.commit()
```

### SwiftUI Debounced Search Pattern

**Modern approach with @Observable (no Combine):**
```swift
// Source: livsycode.com - Debounce in Observable classes
@Observable
final class SearchViewModel {
    var searchText: String = ""
    var debouncedSearchText: String = ""
    private var searchTask: Task<Void, Never>?

    func onSearchTextChanged(_ newValue: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                debouncedSearchText = newValue
            }
        }
    }
}
```

**SwiftUI integration:**
```swift
struct VideoListView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        List { /* videos */ }
            .searchable(text: $viewModel.searchText)
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.onSearchTextChanged(newValue)
            }
            .onChange(of: viewModel.debouncedSearchText) { _, newValue in
                Task { await performSearch(newValue) }
            }
    }
}
```

### SwiftUI Multi-Select Grid Pattern

**Custom selection management (LazyVGrid has no built-in selection):**
```swift
// Source: Multiple SwiftUI community patterns
@Observable
final class SelectionManager {
    var isSelecting: Bool = false
    var selectedIds: Set<UUID> = []

    func toggle(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    func clearSelection() {
        selectedIds.removeAll()
        isSelecting = false
    }
}

struct VideoGridView: View {
    @State private var selection = SelectionManager()
    let videos: [Video]

    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(videos) { video in
                VideoCard(video: video, isSelected: selection.selectedIds.contains(video.id))
                    .onTapGesture {
                        if selection.isSelecting {
                            selection.toggle(video.id)
                        } else {
                            // Navigate to detail
                        }
                    }
                    .onLongPressGesture {
                        selection.isSelecting = true
                        selection.toggle(video.id)
                    }
            }
        }
        .toolbar {
            if selection.isSelecting {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete") { /* bulk delete */ }
                }
            }
        }
    }
}
```

### Bottom Sheet Playbook Picker Pattern

**Using presentationDetents (iOS 16+):**
```swift
struct PlaybookPickerSheet: View {
    @Binding var selectedPlaybook: Playbook?
    let playbooks: [Playbook]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            // Horizontal chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(playbooks) { playbook in
                        PlaybookChip(
                            playbook: playbook,
                            isSelected: selectedPlaybook?.id == playbook.id
                        )
                        .onTapGesture {
                            selectedPlaybook = playbook
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button("See all playbooks") {
                // Navigate to full list
            }
        }
        .presentationDetents([.height(120), .medium])
        .presentationDragIndicator(.visible)
    }
}
```

### Recommended Project Structure
```
backend/app/
├── api/v1/endpoints/
│   ├── playbooks.py      # Playbook CRUD + bulk ops
│   └── videos.py         # Add search endpoint
├── models/
│   ├── playbook.py       # Update with many-to-many
│   └── video.py          # Update with many-to-many + search_vector
├── schemas/
│   ├── playbook.py       # Request/response schemas
│   └── video.py          # Add search schemas

ios/Scrollsmith/
├── Models/
│   ├── Playbook.swift    # Update with many-to-many
│   └── Video.swift       # Update with many-to-many
├── ViewModels/
│   ├── PlaybookViewModel.swift
│   └── SearchViewModel.swift
├── Views/
│   ├── Playbooks/
│   │   ├── PlaybookListView.swift
│   │   ├── PlaybookDetailView.swift
│   │   └── PlaybookPickerSheet.swift
│   └── Videos/
│       ├── VideoGridView.swift
│       └── VideoSearchView.swift
```

### Anti-Patterns to Avoid
- **Client-side search filtering:** Always use PostgreSQL full-text search for performance
- **Eager loading all relationships:** Use lazy loading or explicit joins for many-to-many
- **Storing favorites as boolean on Video:** Use system Playbook (Favorites) for consistency
- **Manual tsvector updates:** Use GENERATED ALWAYS AS for automatic sync

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Full-text search | LIKE queries or regex | PostgreSQL tsvector + GIN | 10-100x faster, handles stemming, ranking |
| Search highlighting | String manipulation | ts_headline() | Handles edge cases, configurable |
| Debounce logic | Manual timers | Task-based cancellation | Built-in cancellation, cleaner code |
| Bulk operations | Loop with individual updates | SQLAlchemy bulk execute | Single query vs N queries |
| Association table management | Manual INSERT/DELETE | SQLAlchemy relationship collections | Automatic handling via .append()/.remove() |

**Key insight:** PostgreSQL's full-text search is production-ready and handles stemming, ranking, and highlighting. Don't reinvent with LIKE or application-side filtering.

## Common Pitfalls

### Pitfall 1: SwiftData iOS 17 Many-to-Many Bug
**What goes wrong:** Many-to-many relationships fail silently based on alphabetical model name ordering
**Why it happens:** Known SwiftData bug in iOS 17.0
**How to avoid:** Always provide default values: `var videos: [Video] = []`
**Warning signs:** Relationships not persisting, empty arrays after fetch

### Pitfall 2: Missing search_vector Index
**What goes wrong:** Search queries become slow as data grows
**Why it happens:** Full table scan instead of index scan
**How to avoid:** Always create GIN index on tsvector column
**Warning signs:** Search latency > 100ms, EXPLAIN shows Seq Scan

### Pitfall 3: ts_headline Performance
**What goes wrong:** Slow search results when generating highlights
**Why it happens:** ts_headline processes original document, not index
**How to avoid:** Limit results FIRST, then apply ts_headline only to top N
**Warning signs:** Search taking > 1s with large transcripts

### Pitfall 4: Async Relationship Access in SwiftData
**What goes wrong:** Crash or empty data when accessing relationships
**Why it happens:** Lazy loading attempts blocking I/O in async context
**How to avoid:** Always fetch relationships within the same ModelContext transaction
**Warning signs:** "Object was deallocated" errors, nil relationships

### Pitfall 5: Playbook Limit Bypass
**What goes wrong:** Free users creating unlimited Playbooks via API
**Why it happens:** Limit enforced only on iOS, not backend
**How to avoid:** Backend validates Playbook count against subscription tier
**Warning signs:** Free users with > 3 Playbooks

### Pitfall 6: Favorites Playbook Deletion
**What goes wrong:** User deletes Favorites, system behavior breaks
**Why it happens:** No protection for system Playbooks
**How to avoid:** Add `is_system` flag, reject deletion of system Playbooks
**Warning signs:** Missing Favorites after user action

## Code Examples

### Backend: Playbook CRUD with Free Tier Limit

```python
# Source: Project patterns from existing endpoints
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/playbooks", tags=["playbooks"])

MAX_FREE_PLAYBOOKS = 3

@router.post("", response_model=PlaybookResponse, status_code=status.HTTP_201_CREATED)
async def create_playbook(
    request: PlaybookCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Playbook:
    # Check free tier limit
    if current_user.subscription_tier == "free":
        count_result = await db.execute(
            select(func.count()).select_from(Playbook).where(
                Playbook.user_id == current_user.id,
                Playbook.is_system == False
            )
        )
        count = count_result.scalar_one()
        if count >= MAX_FREE_PLAYBOOKS:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "playbook_limit_reached",
                    "message": f"Free tier limited to {MAX_FREE_PLAYBOOKS} Playbooks",
                    "upgrade_url": "/subscribe/pro"
                }
            )

    playbook = Playbook(
        user_id=current_user.id,
        name=request.name,
        icon=request.icon,
    )
    db.add(playbook)
    await db.commit()
    await db.refresh(playbook)
    return playbook
```

### Backend: Full-Text Search Endpoint

```python
# Source: PostgreSQL docs + SQLAlchemy patterns
from sqlalchemy import text

@router.get("/search", response_model=VideoSearchResponse)
async def search_videos(
    q: str = Query(..., min_length=1, max_length=200),
    playbook_id: Optional[UUID] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
) -> VideoSearchResponse:
    # Build search query
    search_query = text("""
        SELECT v.id, v.source_url, v.summary_bullets, v.tags, v.created_at,
               ts_rank(v.search_vector, plainto_tsquery('english', :q)) AS rank,
               ts_headline('english', v.transcript, plainto_tsquery('english', :q),
                   'MaxWords=30, MinWords=15, StartSel=<mark>, StopSel=</mark>') AS highlight
        FROM videos v
        WHERE v.user_id = :user_id
          AND v.search_vector @@ plainto_tsquery('english', :q)
          AND (:playbook_id IS NULL OR EXISTS (
              SELECT 1 FROM video_playbooks vp
              WHERE vp.video_id = v.id AND vp.playbook_id = :playbook_id
          ))
        ORDER BY rank DESC
        LIMIT :limit OFFSET :skip
    """)

    result = await db.execute(search_query, {
        "q": q,
        "user_id": current_user.id,
        "playbook_id": playbook_id,
        "limit": limit,
        "skip": skip,
    })

    videos = result.mappings().all()
    return VideoSearchResponse(videos=videos, query=q)
```

### Backend: Bulk Operations

```python
# Source: SQLAlchemy 2.0 docs
@router.post("/bulk-delete", status_code=status.HTTP_204_NO_CONTENT)
async def bulk_delete_videos(
    request: BulkDeleteRequest,  # {"video_ids": [uuid, uuid, ...]}
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    if len(request.video_ids) > 100:
        raise HTTPException(status_code=400, detail="Maximum 100 videos per request")

    stmt = delete(Video).where(
        Video.id.in_(request.video_ids),
        Video.user_id == current_user.id
    )
    result = await db.execute(stmt, execution_options={"synchronize_session": False})
    await db.commit()

    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="No matching videos found")


@router.post("/bulk-move", response_model=BulkMoveResponse)
async def bulk_move_to_playbook(
    request: BulkMoveRequest,  # {"video_ids": [...], "playbook_id": uuid}
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BulkMoveResponse:
    # Verify playbook ownership
    playbook = await db.get(Playbook, request.playbook_id)
    if not playbook or playbook.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Playbook not found")

    # Add videos to playbook (many-to-many association)
    for video_id in request.video_ids:
        await db.execute(
            text("""
                INSERT INTO video_playbooks (video_id, playbook_id)
                VALUES (:video_id, :playbook_id)
                ON CONFLICT DO NOTHING
            """),
            {"video_id": video_id, "playbook_id": request.playbook_id}
        )

    await db.commit()
    return BulkMoveResponse(moved_count=len(request.video_ids))
```

### iOS: Search ViewModel with Debounce

```swift
// Source: livsycode.com + modern SwiftUI patterns
import SwiftUI

@Observable
final class VideoSearchViewModel {
    var searchText: String = ""
    var debouncedQuery: String = ""
    var isSearching: Bool = false
    var results: [VideoSearchResult] = []
    var error: String?

    private var searchTask: Task<Void, Never>?

    func onSearchTextChanged(_ newValue: String) {
        searchTask?.cancel()

        if newValue.isEmpty {
            debouncedQuery = ""
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                debouncedQuery = newValue
            }
        }
    }

    func performSearch(playbook: Playbook? = nil) async {
        guard !debouncedQuery.isEmpty else { return }

        isSearching = true
        error = nil

        do {
            results = try await APIClient.shared.searchVideos(
                query: debouncedQuery,
                playbookId: playbook?.id
            )
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }
}
```

### iOS: Selection Manager for Bulk Operations

```swift
// Source: SwiftUI community patterns
@Observable
final class VideoSelectionManager {
    var isSelecting: Bool = false
    var selectedIds: Set<UUID> = []

    var selectedCount: Int { selectedIds.count }

    func toggle(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }

        // Exit selection mode if nothing selected
        if selectedIds.isEmpty {
            isSelecting = false
        }
    }

    func enterSelectionMode(with id: UUID) {
        isSelecting = true
        selectedIds.insert(id)
    }

    func clearSelection() {
        selectedIds.removeAll()
        isSelecting = false
    }

    func selectAll(_ ids: [UUID]) {
        selectedIds = Set(ids)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Combine for debounce | Task-based with @Observable | iOS 17 (2023) | Simpler code, no Combine dependency |
| LIKE queries | PostgreSQL tsvector | Always was better | 10-100x faster search |
| Core Data relationships | SwiftData @Relationship | iOS 17 (2023) | Cleaner syntax, type-safe |
| @Published + ObservableObject | @Observable | iOS 17 (2023) | Less boilerplate |
| UICollectionView selection | Custom SwiftUI state | iOS 14+ | Still no native grid selection |

**Deprecated/outdated:**
- Combine's `.debounce(for:scheduler:)` in @Observable classes: Use Task-based cancellation instead
- Manual tsvector triggers: Use GENERATED ALWAYS AS columns
- LazyVGrid built-in selection: Does not exist, use custom state

## Open Questions

1. **Migration strategy for many-to-many**
   - What we know: Need to add association table and migrate existing playbook_id data
   - What's unclear: Should existing one-to-many data be preserved or can we do clean migration?
   - Recommendation: Create migration that preserves existing video-playbook relationships by copying to association table, then drop playbook_id column

2. **Favorites Playbook creation timing**
   - What we know: Favorites is a system Playbook that cannot be deleted
   - What's unclear: Create on user registration or on first video save?
   - Recommendation: Create during user registration to ensure it always exists

3. **Search result caching on iOS**
   - What we know: Backend returns search results with highlights
   - What's unclear: Should iOS cache results locally for offline?
   - Recommendation: No caching needed for v1 - search is an online operation

## Sources

### Primary (HIGH confidence)
- [PostgreSQL 18 Full-Text Search Documentation](https://www.postgresql.org/docs/current/textsearch-tables.html) - tsvector, GIN indexes, ts_headline
- [SQLAlchemy 2.0 ORM DML Documentation](https://docs.sqlalchemy.org/en/20/orm/queryguide/dml.html) - Bulk update/delete patterns
- [SQLAlchemy 2.0 Basic Relationships](https://docs.sqlalchemy.org/en/20/orm/basic_relationships.html) - Many-to-many with secondary
- [Hacking with Swift SwiftData Many-to-Many](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-many-to-many-relationships) - SwiftData relationship patterns

### Secondary (MEDIUM confidence)
- [pganalyze GIN Index Guide](https://pganalyze.com/blog/gin-index) - GIN performance considerations
- [Livsy Code Debounce in Observable](https://livsycode.com/swiftui/how-to-use-debounce-in-swiftui-or-in-observable-classes/) - Modern debounce patterns
- [Fat Bob Man SwiftData Relationships](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/) - SwiftData relationship rules

### Tertiary (LOW confidence)
- Community patterns for LazyVGrid selection - No official Apple documentation on grid multi-select

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project, well-documented
- Architecture (PostgreSQL FTS): HIGH - Official PostgreSQL documentation
- Architecture (SwiftData M2M): MEDIUM - Known iOS 17 bugs, community workarounds
- Architecture (SwiftUI selection): MEDIUM - No native support, community patterns
- Pitfalls: HIGH - Well-documented issues with official workarounds

**Research date:** 2026-01-23
**Valid until:** 2026-02-23 (30 days - stable technologies)
