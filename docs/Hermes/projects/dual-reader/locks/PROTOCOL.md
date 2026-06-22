# Lock Protocol — Dual Reader

## Lock files (in this directory)

### interactive.lock
- **Who writes:** Interactive session (when user gives a command involving dual-reader)
- **Who checks:** Worker (before starting)
- **Content:** `{"session":"interactive","acquired":"<ISO timestamp>","ttl_minutes":30}`
- **Rule:** If file exists AND is fresher than `ttl_minutes` → worker SKIPS
- **Stale lock:** If lock older than TTL → ignore

### worker.lock
- **Who writes:** Worker (at start of each run)
- **Who checks:** Interactive session (before modifying files)
- **Content:** `{"worker":"dual-reader","acquired":"<ISO timestamp>","item":"<id>"}`
- **Rule:** If fresh (< 15 min) → interactive waits or warns user
- **Cleanup:** Worker deletes at end of run

## Priority: Interactive ALWAYS wins. Workers yield unconditionally.
