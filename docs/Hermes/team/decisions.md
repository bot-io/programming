# Team Decisions Log

> Append-only. Context / Decision / Rationale format. Never edit prior entries.

## 2026-09-27 — Team layer lives in `docs/Hermes/team/`

- **Context:** Bob opened the Telegram team room and asked for full-team setup + protocols documented in git. Vault already had a per-project protocol (AGENTS.md) but no PM↔Dev coordination layer.
- **Decision:** Create `docs/Hermes/team/` with TEAM-PROTOCOL.md, ROSTER.md, backlog.md, status.md, decisions.md, worklog.md. PM leads product; Dev leads implementation; user oversight is full but non-blocking. Items use `TEAM-NNN` IDs.
- **Rationale:** Keeps single-source-of-truth in git, reuses existing locking/append-only conventions, and matches Bob's stated division of labor ("PM agent in the lead", "full oversight", "work independently").
- **Decided by:** Developer agent (bootstrap), pending PM ratification via ROSTER onboarding.
