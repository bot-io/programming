# Lock Protocol — Critterium

## Lock files (in this directory)

### interactive.lock
- **Who writes:** Interactive session (when user gives a command involving critterium)
- **Who checks:** Workers (before starting)
- **Content:** `{"session":"interactive","acquired":"<ISO timestamp>","ttl_minutes":30}`
- **Rule:** If file exists AND is fresher than `ttl_minutes` → workers SKIP
- **Stale lock cleanup:** If lock is older than TTL → ignore (stale session)
- **Priority:** Interactive ALWAYS wins. Workers yield unconditionally.

### worker.lock
- **Who writes:** Worker (at start of each run)
- **Who checks:** Interactive session (before modifying files)
- **Content:** `{"worker":"<job_name>","acquired":"<ISO timestamp>","item":"CRT-XX"}`
- **Rule:** If lock exists AND is fresher than 15 min → interactive waits or warns user
- **Cleanup:** Worker deletes at end of run (success or failure)

## Flow

### Interactive session:
1. User sends command → check `worker.lock`
2. If worker active → tell user "worker is on CRT-XX, waiting for it to finish" (workers run ~5-10 min max)
3. Create `interactive.lock` with current timestamp
4. Do the work
5. Delete `interactive.lock` when done

### Worker:
1. Start → check `interactive.lock`
2. If interactive active → skip entirely, report "⏸ Interactive session active — yielding"
3. Create `worker.lock`
4. Do the work
5. Delete `worker.lock`
