# Phase 6: Playbooks & Organization - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

CRUD Playbooks, video assignment to Playbooks, full-text search across videos, and bulk operations (delete, move). Users organize their saved videos into collections for easy access.

</domain>

<decisions>
## Implementation Decisions

### Playbook Structure
- Free users: 3 Playbooks max; Pro users: unlimited
- Auto-sort by recent activity (most recently updated first)
- On Playbook delete: confirm dialog asking whether to delete videos or move them to "All Videos"
- System-created "Favorites" Playbook that cannot be deleted (always present)

### Video Assignment Flow
- Videos can belong to multiple Playbooks (many-to-many relationship)
- Assignment optional during capture, can be changed anytime afterward
- Playbook picker UI: bottom sheet with horizontally scrollable chips, single selection at a time, "remember last selected" behavior, "See all playbooks" button opens full-screen list
- Videos without Playbook assignment appear in "All Videos" view (no separate "Uncategorized" label)

### Search Experience
- Search scope is context-aware: in Playbook view = search that Playbook; in All Videos = search all
- Results display in same grid layout as normal video browsing
- Real-time search with debounce (200-300ms) as user types

### Bulk Operations UX
- Enter selection mode via long-press on a video OR explicit "Select" toolbar button
- Simple confirm dialog for bulk delete ("Delete X videos?" with Cancel/Delete)
- No "Select All" button — user selects individually

### Claude's Discretion
- What fields are searchable (recommend: transcript + tags + summary bullets at minimum)
- Which bulk actions to include (recommend: Move + Delete + Add to Favorites)
- Exact debounce timing and empty state designs
- Playbook name character limits and validation rules

</decisions>

<specifics>
## Specific Ideas

- Playbook picker during upload: bottom sheet with horizontally scrollable chips, similar to Instagram's story audience selector
- "Remember last selected" behavior for Playbook picker — reduces friction for users who batch-upload to same Playbook
- Favorites as system Playbook — always accessible, works like iOS Photos favorites

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-playbooks-organization*
*Context gathered: 2026-01-23*
