# Channel Configuration — How Sessions Interact with the Vault

> **Document:** MS-007 — Channel Configuration Documentation  
> **Created:** 2026-06-11  
> **Purpose:** Describe how each Hermes channel (Telegram, CLI, Cron) interacts with the coordination vault at `D:\programming\docs\Hermes\`.

---

## Overview

All Hermes sessions — regardless of how they are initiated — follow the same coordination protocol defined in [AGENTS.md](../AGENTS.md). No channel has special privileges. The vault is the single source of truth for project state, backlog, decisions, and coordination.

The three channels are:

| Channel | Purpose | Initiated By | Session Duration |
|---------|---------|-------------|-----------------|
| **Telegram** | Interactive conversations, quick questions, notifications | User sends message in Telegram chat | Until the conversation ends or gateway timeout |
| **CLI** | Long-running autonomous sessions, batch work, debugging | User runs `hermes` in terminal | Until the user exits or session times out |
| **Cron** | Scheduled tasks, monitoring, automated overnight work | Hermes cron scheduler (time-based) | Bounded — each job runs to completion |

---

## 1. Telegram Sessions

### How They Start
- User sends a message in a Telegram chat connected to the Hermes gateway.
- The gateway creates a session and routes the message to the Hermes agent.
- The gateway is a long-running process (PID in `gateway.pid`, state in `gateway_state.json`).

### Vault Interaction
- **Session Start Ritual:** Every Telegram session should read `PRIORITIES.md` and `status/subscription.md` before working, per AGENTS.md §1.
- **Project Scope:** If working on a specific project, the session reads that project's `charter.md`, `state.md`, `backlog.md`, and `questions.md`.
- **Locking:** Before autonomous work on a project, the session creates `locks/<project-name>.lock` with its session ID, timestamp, and item being worked on. The lock is removed when done.
- **Append-Only Logs:** Worklogs (`worklog.md`) and decisions (`decisions.md`) are appended to, never edited.
- **Backlog Updates:** When completing or blocking an item, the session updates the item's status in `backlog.md`.
- **Dashboard Refresh:** After vault changes, the session runs `python "C:\Users\Svetlin\AppData\Local\hermes\scripts\update-now-dashboard.py"` to refresh `status/now.md`.

### Delivery
- All responses are delivered back to the Telegram chat where the conversation started.
- Cron jobs with `"deliver": "origin"` send output to the originating Telegram chat.

### Telegram Chats in Use
- **Bob** (chat_id: `7022318141`) — Primary personal chat for monitoring alerts.
- **Hermes General Setup** (chat_id: `-1003983495710`) — Group chat for overnight worker output, morning digest, and setup discussions.

### Constraints
- Telegram sessions are interactive — they can ask clarifying questions.
- Gateway timeout is 1800 seconds (30 minutes) by default.
- Sessions respect `worker.lock` — if the overnight worker is running, Telegram sessions should not overlap on the same project.

---

## 2. CLI Sessions

### How They Start
- User runs `hermes` from a terminal on the local machine.
- The session uses the same `config.yaml` and profile as Telegram sessions.

### Vault Interaction
- **Same protocol as Telegram** — the AGENTS.md coordination rules apply identically.
- **Session Start Ritual:** Read `PRIORITIES.md` and `status/subscription.md`.
- **Project Scope:** Declare and focus on one project at a time.
- **Locking:** Create `locks/<project-name>.lock` before autonomous work. Respect `worker.lock`.
- **Append-Only Logs:** Same append-only discipline for `worklog.md` and `decisions.md`.
- **Dashboard Refresh:** Same `update-now-dashboard.py` call after vault changes.

### Advantages Over Telegram
- Longer-running — no gateway timeout (session lives as long as the terminal is open).
- More tools available — full terminal access, file operations, web extraction.
- Better for complex multi-step work like refactoring, large test suites, or debugging.

### Constraints
- CLI sessions must still follow the vault protocol — they are not exempt from locking or append-only rules.
- If a `worker.lock` exists and is less than 90 minutes old, CLI sessions should wait (the overnight worker is running).

---

## 3. Cron Jobs

### How They Start
- Scheduled by the Hermes cron scheduler (`~/.hermes/cron/jobs.json`).
- Each job has a defined schedule (interval or cron expression) and a prompt or script.
- Jobs run automatically with no user interaction.

### Active Cron Jobs

| Job | Schedule | Type | Script/Agent | Delivery |
|-----|----------|------|-------------|----------|
| **Z.AI Token Usage Monitor** | Every 10 minutes | Script (`no_agent: true`) | `zai-quota-check.py` → `zai_quota.py` | Telegram (Bob chat) |
| **Overnight Worker** | Hourly, 23:00–06:00 | Full agent | AGENTS.md protocol | Telegram (Hermes General Setup) |
| **Morning Digest** | Daily at 07:30 | Script (`no_agent: true`) | `morning-digest.py` | Telegram (Hermes General Setup) |
| **Nightly Transcript Export** | Daily at 03:00 | Script (`no_agent: true`) | `export-transcripts.py` | Local (file) |

### Vault Interaction by Job

#### Z.AI Token Usage Monitor
- **Reads:** Calls Z.AI API to check token usage.
- **Writes:** Updates `status/subscription.md` and appends to `status/usage-history.csv`.
- **Vault Impact:** Low — reads subscription state, writes to shared status files.
- **Note:** This is the only job that writes to `status/subscription.md` and `status/usage-history.csv` (user/script-owned files per AGENTS.md §4).

#### Overnight Worker
- **Reads:** `status/subscription.md`, `status/worker-state.json`, all project `backlog.md` files.
- **Writes:** `locks/worker.lock` (at start), project `backlog.md` (status updates), `worklog.md` (append), `state.md` (updates), `status/worker-state.json` (at end).
- **Vault Impact:** High — this is the main autonomous worker. It picks one backlog item per run, implements it, opens a PR, and updates all project tracking files.
- **Protocol:** Follows AGENTS.md exactly — quota check, lock check, round-robin project selection, implementation, cleanup.

#### Morning Digest
- **Reads:** All project state files, backlog summaries, subscription status.
- **Writes:** Generates a summary digest. May write to vault for dashboard refresh.
- **Vault Impact:** Low to medium — primarily reads, produces a human-readable summary.

#### Nightly Transcript Export
- **Reads:** Session transcripts from Hermes state database.
- **Writes:** Exports to local file storage.
- **Vault Impact:** Minimal — does not modify vault files directly.

### Cron-Specific Rules
- **Locking:** The Overnight Worker creates `locks/worker.lock` at the start of each run and removes it during cleanup. Other sessions must respect this lock.
- **No Interaction:** Cron jobs cannot ask questions. If ambiguity is encountered, items are marked `needs-decision` and questions are written to `questions.md`.
- **Error Handling:** If a cron job fails, the error is logged in `jobs.json` (`last_error` field). The overnight worker has explicit quota-error handling to preserve remaining capacity.

---

## 4. Coordination Between Channels

### Locking System
- **`locks/worker.lock`** — Created only by the Overnight Worker cron job. Any other session seeing this lock (less than 90 min old) must wait.
- **`locks/<project-name>.lock`** — Created by any session (Telegram, CLI, or cron) when actively working on a project. Other sessions skip that project.
- Lock files contain: session ID, timestamp, project name, and current item.

### Shared State Files
| File | Written By | Read By |
|------|-----------|---------|
| `status/subscription.md` | Z.AI Monitor (cron) | All sessions |
| `status/usage-history.csv` | Z.AI Monitor (cron) | All sessions |
| `status/worker-state.json` | Overnight Worker (cron) | All sessions |
| `status/now.md` | `update-now-dashboard.py` (any session) | Human (Obsidian) |
| `PRIORITIES.md` | User only | All sessions (read-only for agents) |
| Project `backlog.md` | Any session working on that project | All sessions |
| Project `state.md` | Any session working on that project | All sessions |
| Project `worklog.md` | Any session working on that project (append) | All sessions |
| Project `decisions.md` | Any session working on that project (append) | All sessions |

### Conflict Avoidance
1. Only one session works on a project at a time (enforced by per-project locks).
2. The overnight worker works across ALL projects sequentially (enforced by `worker.lock`).
3. All vault writes are committed to git after each significant change.
4. The dashboard (`status/now.md`) is refreshed after every vault mutation, giving all channels a consistent view.

---

## 5. Confirmation: All Channels Follow AGENTS.md

| AGENTS.md Rule | Telegram | CLI | Cron (Worker) | Cron (Monitor) |
|---------------|----------|-----|---------------|----------------|
| Session Start Ritual (§1) | ✅ Reads PRIORITIES.md, subscription.md | ✅ Same | ✅ Same (quota check first) | ✅ N/A (script-based) |
| One project per session (§2) | ✅ Declares project scope | ✅ Same | ✅ Picks one project per run | ✅ N/A |
| Append-only logs (§3) | ✅ Appends to worklog.md, decisions.md | ✅ Same | ✅ Same | ✅ N/A |
| Only "ready" items (§3) | ✅ Checks status before work | ✅ Same | ✅ Same | ✅ N/A |
| Never guess on ambiguity (§3) | ✅ Asks user or writes to questions.md | ✅ Same | ✅ Marks needs-decision | ✅ N/A |
| Testing required (§3) | ✅ Runs test suite | ✅ Same | ✅ Same | ✅ N/A |
| Feature branches + PRs (§3) | ✅ Creates feat/ branches | ✅ Same | ✅ Same | ✅ N/A |
| Vault commits after writes (§3) | ✅ Commits to git | ✅ Same | ✅ Same | ✅ N/A |
| Shared layer read-only (§4) | ✅ Never writes to subscription.md | ✅ Same | ✅ Worker reads only; Monitor writes | ✅ Monitor is the designated writer |
| Locking protocol (§5) | ✅ Creates/respects project locks | ✅ Same | ✅ Creates worker.lock; respects project locks | ✅ N/A |
| Dashboard refresh | ✅ Runs update-now-dashboard.py | ✅ Same | ✅ Same (in cleanup step) | ✅ Done by monitor script |

**Conclusion:** All three channels follow the AGENTS.md coordination protocol. The Z.AI Usage Monitor is the designated writer for `status/subscription.md` and `status/usage-history.csv` (as noted in AGENTS.md §4, these are "user/script-owned"). No contradictions exist.
