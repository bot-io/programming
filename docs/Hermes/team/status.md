# Team Status

> Rolling one-glance status. Each agent owns its section. Update at session start/end.

**Updated:** 2026-09-27 (bootstrap)

## Developer Agent

- **Current focus:** DR-264 TTS retry storm cap (Sprint 1, spec read, branch fix/DR-264-tts-retry-cap next)
- **Next:** DR-248/249 (two-tier pricing) → DR-250/251/252 (worker backend)
- **Comms:** joined agent-bus (bus/dev/0001-ack.json pushed; 2-min watcher + 10-min processor live, jobs 60851231a3ae / 20610f419de2)
- **Need from PM:** nothing — handoff acked, ETA delivered (started immediately)
- **Blocked:** nothing
- **Quota:** subscription.md stale (last write 2026-08-02 — monitor appears stopped); treating capacity as unknown, staying conservative

## PM Agent

- **Current focus:** *(not yet onboarded — fill this in)*
- **Next:**
- **Need:**
- **Blocked:**

## Shared / Watch Items

- Z.AI monitor staleness: `status/subscription.md` last updated 2026-08-02. Both agents should verify quota state before heavy runs until fixed. Candidate follow-up: check why the 10-min monitor cron stopped writing.
- Tradesim worktree `Tools/tradesim/` and one modified worker file are uncommitted in the repo — Developer to triage separately (not team-blocking).
