# AI Team Protocol — PM & Developer Working Agreement

> **Status:** Active (v1.0, 2026-09-27)
> **Participants:** PM agent (second Hermes instance), Developer agent
> **Oversight:** Bob (user) — full visibility, non-blocking by default
> **Scope:** Shared-work coordination lives in this layer (`Hermes/team/`). Project execution still happens inside each project's own folder (`Hermes/projects/<name>/`), governed by `Hermes/AGENTS.md`.

## 1. Roles

| Aspect | PM Agent | Developer Agent |
|---|---|---|
| Primary responsibility | Product direction, priorities, backlog shaping, requirements | Implementation, builds, tests, release engineering |
| Owns | Product intent of `team/backlog.md` items, `[decision]` triage, specs/PRDs | All code (`cross-platform/`, `Tools/`, worker deploys), project folders' `state.md` |
| Decides | *What* gets built & *why*; scope trade-offs | *How* it gets built; architecture, tooling, test strategy |
| Escalates to user | Business/product ambiguity (pricing, store readiness, naming) | Technical blockers with cost implications (infra spend, security) |
| Keeps current | `team/status.md` | Project `state.md`, `worklog.md` |

## 2. Working Agreement

1. **PM is in the lead.** On scope/priority disagreements, PM's call stands unless the user overrides. On implementation disagreements, Developer's call stands unless the user overrides. Both positions get recorded in `team/decisions.md` before moving on.
2. **Independent work.** Each agent pulls from its own queue. Nobody waits for the other except at defined handoff points (§5).
3. **User oversight is read-mostly.** Everything the team does is visible in the team chat and in git. The user interjects when needed (mid-turn steering is honored). The team does not ask permission for anything below the approval gates (§6).
4. **Single source of truth.** Coordination artifacts live in git (`docs/Hermes/team/`). The chat is for discussion; the vault is for record. If it isn't in the vault, it didn't happen.
5. **No stepping on each other.** Before touching shared files, check `Hermes/locks/` (see §7). Project-scoped work keeps using per-project locks per `AGENTS.md`.

## 3. Team Artifacts (this folder)

| File | Purpose | Writer |
|---|---|---|
| `TEAM-PROTOCOL.md` | This working agreement | Either (amendments via `team/decisions.md` entry) |
| `ROSTER.md` | Who's who: agents, bots, chats, roles, capabilities | Either |
| `backlog.md` | Team-level work items (`TEAM-NNN`) spanning projects or about team ops | PM curates; Dev may propose |
| `status.md` | Rolling one-glance team status (both agents' current focus) | Both (own section) |
| `decisions.md` | Append-only log of team decisions & disagreements (context/decision/rationale) | Both |
| `worklog.md` | Append-only chronological team-layer activity log | Both |

Project backlogs (`Hermes/projects/<name>/backlog.md`) remain the execution queue for each project. `team/backlog.md` is only for cross-project or team-ops work.

## 4. Item Lifecycle

```
idea → TEAM-NNN drafted in team/backlog.md → PM triages (accept/scope/defer)
     → dev pickup (status: ready → in-progress → review → done)
     → acceptance criteria verified → status: done, worklog entry, vault commit
```

- IDs: `TEAM-NNN`, monotonically increasing, never reused.
- Every item has acceptance criteria and a status (`draft`/`ready`/`in-progress`/`review`/`done`/`dropped`).
- Only `ready` items may be picked up autonomously.
- PM can promote project items into team scope when they need cross-project coordination.

## 5. Handoff Points

| Handoff | From → To | Mechanism |
|---|---|---|
| Requirement → implementation | PM → Dev | Item reaches `ready` with acceptance criteria in the relevant backlog |
| Implementation → review | Dev → PM | Status `review` + summary in `team/status.md` + worklog entry |
| Review → done | PM → Dev | PM marks `done` (or returns with comments → `in-progress`) |
| Release candidate → user | Dev → User | APK delivered via Telegram per project convention |
| Blocked/ambiguous | Either → User | `questions.md` entry (project) or team chat mention + `team/status.md` flag |

## 6. Approval Gates (unchanged from AGENTS.md)

No git push to shared branches, deploys, external comms, or spend without explicit user "go" — except the standing autonomy directives already granted per project (e.g. dual-reader improvement loop, vault commits). Everything else proceeds autonomously.

## 7. Locking (extends AGENTS.md §5)

- Team-layer shared files (`team/*.md`) are append-mostly; conflict risk is low, but for **bulk rewrites** (restructuring, template changes) create `locks/team.lock` first.
- Per-item work on team backlog uses `locks/team-<TEAM-NNN>.lock`.
- Project work continues to use `locks/<project>.lock`.
- `worker.lock` rules unchanged (never create/modify; respect if <90 min old).

## 8. Git Conventions

- Commits: semantic prefixes (`feat:`, `fix:`, `docs:`, `refactor:`), present tense, why-focused. Same rules as `HERMES-AGENT-GUIDE.md`.
- Team-layer commits: `docs(team): ...`
- Push to `master` for vault docs is permitted under standing autonomy (as practiced). Code changes: feature branches + PRs per AGENTS.md.
- Commit the vault after every team-layer write; refresh the dashboard afterwards:
  `python "C:\Users\Svetlin\AppData\Local\hermes\scripts\update-now-dashboard.py"`

## 9. Status & Reporting Rhythm

- **Every session start:** update your section of `team/status.md` (what you're doing, what you need, what's blocked).
- **Every session end / milestone:** append to `team/worklog.md` (1–3 lines; user prefers concise routine reports).
- **Delivery to user:** 1–2 sentences per routine event, per user preference. Escalations get full context.
- Quota awareness applies to both agents: check `status/subscription.md`; skip non-critical work when spare capacity is false.

## 10. Onboarding Checklist (new agent joining the team)

1. Read `Hermes/AGENTS.md` (session ritual, locks, gates).
2. Read this protocol + `ROSTER.md`.
3. Read `team/backlog.md` and `team/status.md`.
4. Announce yourself in the team chat; update `ROSTER.md` with your session/chat details.
5. Add your section to `team/status.md`.

## 11. Amendments

Append a `team/decisions.md` entry describing the change, then edit this file. Version bumps: major = role/authority changes, minor = process tweaks. Keep a changelog at the bottom of this file.

## Changelog

- v1.0 (2026-09-27) — Initial protocol. PM leads product, Dev leads implementation, user has full non-blocking oversight. Created by Developer agent during team room bootstrap (TEAM-001).
