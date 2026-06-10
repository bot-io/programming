# Machine Setup — Project Charter

## Summary
Setting up the Hermes multi-session coordination infrastructure on this machine: Obsidian vault, monitoring scripts, cron jobs, and all supporting tooling.

## Repository
`D:\programming\`

## Scope
This project covers the one-time and ongoing setup of:
1. Hermes vault folder structure under `docs/Hermes/`
2. Multi-session coordination protocol (AGENTS.md)
3. Subscription/usage monitoring automation
4. Cron job scheduling for periodic tasks
5. Obsidian vault integration for human-readable project tracking
6. Cross-project decision logging and locking mechanisms
7. Channel configuration (Telegram, CLI, cron)
8. Documentation and onboarding for the coordination system

## Goals
- Enable multiple Hermes sessions to coordinate safely on the same machine
- Provide a human-readable, Obsidian-friendly project tracking layer
- Automate usage monitoring and alerting
- Establish repeatable protocols that work across all channels

## Constraints
- All vault files live under `D:\programming\docs\Hermes\`
- The vault must be committed to git alongside code
- Agents must not modify user/script-owned files (PRIORITIES.md, status/)
