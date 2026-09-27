# Team Decisions Log

> Append-only. Context / Decision / Rationale format. Never edit prior entries.

## 2026-09-27 — Team layer lives in `docs/Hermes/team/`

- **Context:** Bob opened the Telegram team room and asked for full-team setup + protocols documented in git. Vault already had a per-project protocol (AGENTS.md) but no PM↔Dev coordination layer.
- **Decision:** Create `docs/Hermes/team/` with TEAM-PROTOCOL.md, ROSTER.md, backlog.md, status.md, decisions.md, worklog.md. PM leads product; Dev leads implementation; user oversight is full but non-blocking. Items use `TEAM-NNN` IDs.
- **Rationale:** Keeps single-source-of-truth in git, reuses existing locking/append-only conventions, and matches Bob's stated division of labor ("PM agent in the lead", "full oversight", "work independently").
- **Decided by:** Developer agent (bootstrap), pending PM ratification via ROSTER onboarding.

## 2026-09-27 — Team setup extracted to standalone reusable repo `bot-io/team-setup`

- **Context:** Bob directed the team setup to live in its own git repo for reuse across projects, with best practices for both dev work (TDD, coverage) and PM work (requirements, roadmap, oversight, commercial success) included, and PM formally in the lead owning backlog + roadmap.
- **Decision:** Created `bot-io/team-setup` (clone at `D:\bot-io-parent\team-setup`): charter, protocol, `pm/` practices, `dev/` practices, shared templates. This vault's team layer remains the live project instance; the kit is the canonical source. Protocol bumped to v1.1.
- **Rationale:** Reusability across projects + single canonical source for roles/rituals/practices while keeping project-specific coordination state in the project repo.
- **Decided by:** Developer agent per user directive.
