# Hermes Multi-Session Coordination Protocol

All Hermes sessions — regardless of channel — must follow this protocol exactly.

## 1. SESSION START RITUAL

Every session **must** perform the following steps before any work:

1. Read `PRIORITIES.md` — the user's current priorities and directives.
2. Read `status/subscription.md` — current subscription/usage state (written by monitoring script).
3. Declare project scope — announce which project this session will work on.

No work may begin until all three steps are completed.

## 2. PROJECT SCOPE

- Each session works on **exactly one project** at a time.
- Before starting work, read the following files for the chosen project:
  - `charter.md` — project definition, goals, constraints
  - `state.md` — current status summary
  - `backlog.md` — work items with IDs, acceptance criteria, statuses
  - `questions.md` — open questions awaiting user input

## 3. WORK RULES

### Append-Only Logs
- Worklogs (`worklog.md`) and decision logs (`decisions.md`) are **append-only**.
- Never delete, edit, or reorder existing entries.

### Backlog Discipline
- Every backlog item has a unique ID (`ITEM-NNN`), explicit acceptance criteria, and a status.
- Only items with status **"ready"** may be worked on autonomously.
- Items with status `needs-decision`, `blocked`, or `in-progress` require clarification before action.

### Ambiguity Protocol
- **Never guess** on ambiguity.
- If something is unclear, write the question to the project's `questions.md` and move to the next ready item.

### Testing
- Every code change **must** have automated tests.
- The full test suite must be green before any commit.

### Branching
- Autonomous work goes to **feature branches + PRs**, never directly to `main`.
- The user reviews and merges at their discretion.

### Vault Commits
- Commit the vault (`docs/`) after every significant write (backlog updates, decisions, worklog entries, state changes).

## 4. SHARED LAYER

The following are **user/script-owned** — agents **must never** write to them:
- `status/subscription.md`
- `status/usage-history.csv`
- `PRIORITIES.md`

These are maintained by the user and/or automated monitoring scripts. Agents may read them for context but must not modify them.

## 5. LOCKING

Before beginning autonomous work:
1. Check `locks/` for any active locks on the target project.
2. If a lock exists and is recent (within the session's expected duration), **do not start work** — coordinate with the locking session.
3. If no active lock exists, create a lock file containing:
   - Session ID
   - Timestamp
   - Project being worked on
4. Remove the lock file when the session ends or moves to a different project.

## 6. CHANNELS

All channels obey the same protocol:
- **Telegram** — interactive sessions, quick questions, notifications
- **CLI** — long-running autonomous sessions, batch work
- **Cron** — scheduled tasks, monitoring, automated updates

No channel has special privileges. The protocol is channel-agnostic.
