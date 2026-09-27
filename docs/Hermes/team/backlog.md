# Team Backlog

> Cross-project & team-ops items. Project execution stays in `Hermes/projects/<name>/backlog.md`.
> PM curates. IDs: `TEAM-NNN`. Statuses: draft / ready / in-progress / review / done / dropped.

### TEAM-001: Team Layer Bootstrap
- **Status:** in-progress *(criteria 1–3 ✅ done 2026-09-27, commit f138fb7; awaiting PM onboarding — criterion 4)*
- **Priority:** P0
- **Owner:** Developer
- **Acceptance Criteria:**
  1. `docs/Hermes/team/` exists with protocol, roster, backlog, status, decisions, worklog
  2. Team layer linked from `Home.md` and `AGENTS.md`
  3. All files committed & pushed to `bot-io/programming` master
  4. PM agent onboards: fills ROSTER entry, adds status section, announces in team room
- **Notes:** Bootstrap performed by Developer agent on team room opening (2026-09-27).

### TEAM-002: PM Backlog Triage Pass
- **Status:** draft
- **Priority:** P1
- **Owner:** PM
- **Acceptance Criteria:**
  1. PM reviews dual-reader backlog (242+ done items, remaining open items) and current `PRIORITIES.md`
  2. PM proposes the top 3–5 next work items for dual-reader with product rationale (public release focus per Bob's goal)
  3. Proposal posted in team room + recorded in `team/status.md`; Bob can veto/redirect
- **Notes:** First substantive PM task after onboarding. Goal context: polish + publicly release dual-reader (user value + revenue: FREE 10 AI pg/day tier, PREMIUM $5.99/mo / $39.99/yr with 7-day trial).

### TEAM-003: Weekly Team Sync (recurring, optional)
- **Status:** draft
- **Priority:** P2
- **Owner:** PM
- **Acceptance Criteria:**
  1. Decide (with Bob) whether a recurring weekly digest cron is wanted
  2. If yes: cron job delivering a 5-line summary (per-agent focus, done, next, blockers) to the team room
  3. If no: mark dropped with rationale
- **Notes:** Bob dislikes verbose routine reports — keep it minimal if implemented.
