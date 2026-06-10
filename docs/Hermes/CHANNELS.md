# Hermes Channel Configuration

This document describes how each channel (Telegram, CLI, Cron) interacts with the Hermes coordination vault at `D:\programming\docs\Hermes\`.

All channels obey the same protocol defined in [AGENTS.md](AGENTS.md) — no channel has special privileges.

---

## 1. Telegram Sessions

### Configuration
- **Gateway:** Hermes gateway runs as a persistent process on the host machine
- **State file:** `C:\Users\Svetlin\AppData\Local\hermes\gateway_state.json`
- **Connected channels (see `channel_directory.json`):**
  - **Bob (DM, ID `7022318141`):** Primary 1:1 interactive session
  - **Hermes General Setup (Group, ID `-1003983495710`):** Project coordination group
  - **Particle System app (Group, ID `-1003768319025`):** App-specific group
- **Platform toolsets:** `hermes-telegram`

### How Telegram interacts with the vault
1. **Session start:** When a Telegram message arrives, the Hermes gateway dispatches an agent. If the system prompt or skill references AGENTS.md, the agent performs the session start ritual (read PRIORITIES.md, read subscription.md, declare project scope).
2. **Locking:** The agent creates a project-specific lock file at `locks/<project-name>.lock` containing session ID, timestamp, and the item being worked on. This prevents the overnight worker from interfering with the active session.
3. **Vault reads:** The agent reads `charter.md`, `state.md`, `backlog.md`, and `questions.md` for the declared project.
4. **Vault writes:** The agent writes to append-only logs (`worklog.md`, `decisions.md`), updates `state.md` and `backlog.md` as needed, and commits vault changes to git.
5. **Lock cleanup:** The agent removes its project lock when done or when switching projects.
6. **Important:** Telegram agents **never** create or modify `worker.lock` — that belongs exclusively to the overnight worker cron.

### Workflow
```
User sends message → Gateway dispatches agent → Agent reads vault context
→ Agent performs work → Agent writes results to vault → Agent commits to git
→ Agent removes project lock → Response delivered to user
```

---

## 2. CLI Sessions

### Configuration
- **Interface:** `hermes-cli` (terminal-based)
- **Config:** `C:\Users\Svetlin\AppData\Local\hermes\config.yaml` (interface: cli)
- **Platform toolsets:** `browser`, `clarify`, `code_execution`, `computer_use`, `cronjob`, `delegation`, `file`, `image_gen`, `memory`, `messaging`, `session_search`, `skills`, `terminal`, `todo`, `tts`, `vision`, `web`

### How CLI interacts with the vault
1. **Session start:** When the user launches a CLI session, the agent (if instructed) performs the same session start ritual as Telegram — read PRIORITIES.md, read subscription.md, declare project scope.
2. **Locking:** Same as Telegram — creates `locks/<project-name>.lock`, respects `worker.lock` (stops if overnight worker is running).
3. **Full tool access:** CLI sessions have the broadest toolset (file, terminal, web, browser, code execution, etc.), making them ideal for complex implementation tasks, debugging, and long-running work.
4. **Vault reads/writes:** Identical to Telegram — reads project context, writes to append-only logs, updates state and backlog, commits to git.
5. **Interactive approvals:** CLI sessions run with `approvals.mode: manual`, so destructive operations require explicit user confirmation.

### Typical use cases
- Long-running autonomous sessions for complex features
- Batch work across multiple files
- Debugging with full terminal access
- Manual vault maintenance and review

---

## 3. Cron Jobs

### Configuration
- **Cron system:** Hermes built-in cron (`C:\Users\Svetlin\AppData\Local\hermes\cron\jobs.json`)
- **Scripts directory:** `C:\Users\Svetlin\AppData\Local\hermes\scripts\`

### Active cron jobs

| Job | Schedule | Type | Script | Deliver To |
|-----|----------|------|--------|------------|
| Z.AI Token Usage Monitor | Every 10 minutes | `no_agent` (script) | `zai-quota-check.py` | Telegram DM (Bob) |
| Overnight Worker | Hourly (23:00–06:00 Sofia) | Agent (full) | AGENTS.md protocol | Hermes General Setup (Telegram) |
| Morning Digest | 07:30 daily | `no_agent` (script) | `morning-digest.py` | Hermes General Setup (Telegram) |
| Nightly Transcript Export | 03:00 daily | `no_agent` (script) | `export-transcripts.py` | Local only |

### How cron jobs interact with the vault

#### Script-based jobs (`no_agent: true`)
These run Python scripts directly without invoking an LLM agent:
1. **Read vault state:** Scripts read `status/subscription.md`, `status/usage-history.csv`, project `backlog.md`, `worklog.md`, `questions.md`, and lock files.
2. **Write vault state:** Scripts may write to `status/subscription.md`, `status/usage-history.csv`, and `status/.alert-state.json`.
3. **No locking:** Script-based jobs do not create project locks or `worker.lock`. They are lightweight and read-only (or write only to shared status files).
4. **Output delivery:** Results are sent to the configured Telegram chat or kept local.

#### Agent-based jobs (`no_agent: false`)
The Overnight Worker is the only agent-based cron job:
1. **Lock acquisition:** Creates `locks/worker.lock` with current timestamp. Checks for and respects per-project locks (skips locked projects).
2. **Full AGENTS.md protocol:** Follows the multi-step protocol — quota check, lock check, project round-robin, item selection, implementation, PR creation, cleanup.
3. **Vault writes:** Updates `backlog.md`, `worklog.md`, `state.md`, `worker-state.json` during execution.
4. **Git integration:** Commits all vault changes after each run. Pushes feature branches and creates PRs.
5. **Lock cleanup:** Removes `worker.lock` on completion or error.
6. **Dashboard refresh:** Runs `update-now-dashboard.py` after vault changes.

### Important: Shared layer
The following files are **user/script-owned** — cron agents must never modify them:
- `status/subscription.md` (written by `zai-quota-check.py`)
- `status/usage-history.csv` (written by `zai-quota-check.py`)
- `PRIORITIES.md` (maintained by the user)

---

## 4. Channel Comparison

| Aspect | Telegram | CLI | Cron (Agent) | Cron (Script) |
|--------|----------|-----|-------------|---------------|
| **Initiated by** | User message | User command | Schedule | Schedule |
| **LLM agent** | Yes | Yes | Yes | No |
| **Tool access** | `hermes-telegram` | Full suite | Terminal, File, Web | Python only |
| **Locks created** | `<project>.lock` | `<project>.lock` | `worker.lock` + project locks | None |
| **Reads vault** | Yes | Yes | Yes | Yes |
| **Writes vault** | Yes | Yes | Yes | Status files only |
| **Git commits** | Yes | Yes | Yes | No |
| **Interactive** | Yes | Yes | No | No |
| **Deliver to** | Telegram chat | Terminal | Telegram group | Telegram / local |

---

## 5. Protocol Compliance

All three channels follow the AGENTS.md protocol:

1. **Session start ritual:** Read PRIORITIES.md → Read subscription.md → Declare project scope. (Cron agents and scripts do this programmatically.)
2. **One project per session:** Each session works on exactly one project at a time.
3. **Append-only logs:** `worklog.md` and `decisions.md` are never edited retroactively.
4. **Backlog discipline:** Only "ready" items are worked on autonomously.
5. **Feature branches + PRs:** Autonomous work goes to feature branches, never directly to master.
6. **Vault commits:** Significant vault writes are committed to git.
7. **Dashboard refresh:** `update-now-dashboard.py` runs after vault changes.
8. **Locking:** All channels respect the locking mechanism — Telegram/CLI use per-project locks, the overnight worker uses `worker.lock`.
9. **Shared layer:** No channel writes to user/script-owned files.
10. **Ambiguity protocol:** When in doubt, write to `questions.md` and stop.
