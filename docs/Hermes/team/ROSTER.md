# Team Roster

> Last updated: 2026-09-27

## Humans

| Name | Role | Contact |
|---|---|---|
| Bob | Owner / product owner / final authority | Telegram (this team room) |

## Agents

| Agent | Role | Telegram bot | Channel presence | Profile |
|---|---|---|---|---|
| Developer agent | Implementation, builds, tests, releases | `@Svetlin_R2D2_bot` | Team room + project chats | Hermes profile: `default` |
| PM agent | Product direction, backlog, priorities | *TBD — PM fills this in on onboarding* | Team room | Hermes profile: separate instance |

## Capabilities & Notes

- **Developer agent:** local filesystem on Bob's machine (`D:\programming` repo access), full toolset (terminal, browser, file ops, cron), runs the dual-reader improvement loop (cron, 90-min cadence), builds/signs APKs and delivers via Telegram.
- **PM agent:** second Hermes instance run by Bob. Profile/isolated memory per Bob's setup. *PM: append your capabilities here at onboarding.*
- Both agents: read access to the full vault (`docs/Hermes/`), git push to `bot-io/programming` master for docs.

## Coordination Plane

- **Team room (this Telegram group `Svetlin_Herkes_AI_Team`)** — primary coordination channel. Bob has full oversight here.
- **Vault layer `docs/Hermes/team/`** — durable record (this folder).
- Project-specific chats remain for project work (e.g. Particle System app, Hermes General Setup cron deliveries).
