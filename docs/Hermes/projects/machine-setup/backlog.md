# Machine Setup — Backlog

### MS-001: Create Hermes Vault Folder Structure
- **Status:** done
- **Priority:** P0
- **Acceptance Criteria:**
  1. All directories exist: status/, decisions/, locks/, logs/, projects/dual-reader/, projects/machine-setup/
  2. AGENTS.md protocol file is present and complete
  3. PRIORITIES.md placeholder exists
  4. .gitkeep files in empty directories (locks/, logs/)
  5. All files committed to git
- **Notes:** Foundation for everything else. Must be first.

### MS-002: Create Dual-Reader Project Files
- **Status:** done
- **Priority:** P0
- **Acceptance Criteria:**
  1. charter.md with full tech stack and feature list
  2. backlog.md with at least 6 items (DR-001 through DR-006), each with ID, acceptance criteria, status, priority
  3. state.md with current project status
  4. Empty append-only files: decisions.md, worklog.md
  5. Empty questions.md
- **Notes:** Populated from existing project knowledge.

### MS-003: Create Machine-Setup Project Files
- **Status:** done
- **Priority:** P0
- **Acceptance Criteria:**
  1. charter.md defining setup scope
  2. backlog.md with 8 items (MS-001 through MS-008)
  3. state.md set to "in progress"
  4. Empty append-only files: decisions.md, worklog.md
  5. Empty questions.md
- **Notes:** This project tracks its own setup tasks.

### MS-004: Subscription Usage Monitoring Script
- **Status:** done
- **Priority:** P1
- **Acceptance Criteria:**
  1. Script reads current usage data from API/provider
  2. Writes structured data to status/subscription.md
  3. Appends row to status/usage-history.csv with timestamp, usage_pct, next_reset_sofia, spare_capacity, threshold_alert
  4. Script is idempotent and safe to run via cron
  5. Threshold alert triggers when usage exceeds configurable limit
- **Notes:** Implemented as zai_monitor_vault.py. Runs every 10m via cron. Sends Telegram alerts at 80%/95%.

### MS-005: Cron Job Scheduling
- **Status:** done
- **Priority:** P1
- **Acceptance Criteria:**
  1. Monitoring script runs on a defined schedule (e.g., every 6 hours)
  2. Cron configuration is documented and reproducible
  3. Cron jobs follow the AGENTS.md protocol (read shared layer, respect locks)
  4. Failed cron runs produce logs in logs/ directory
- **Notes:** 4 cron jobs active: usage monitor (10m), worker (hourly 23-07), digest (07:30), transcript export (03:00).

### MS-006: Obsidian Vault Integration
- **Status:** done
- **Priority:** P1
- **Acceptance Criteria:**
  1. Vault is openable in Obsidian as a valid vault
  2. All markdown files render correctly with proper linking
  3. Navigation between projects, backlog, and state is intuitive
  4. .obsidian/ config committed (or explicitly excluded) per user preference
- **Notes:** Registered in Obsidian via obsidian.json. Consolidated structure.

### MS-007: Channel Configuration Documentation
- **Status:** done
- **Priority:** P2
- **Acceptance Criteria:**
  1. Document how Telegram sessions interact with the vault
  2. Document how CLI sessions interact with the vault
  3. Document how cron jobs interact with the vault
  4. All three channels confirmed to follow AGENTS.md protocol
- **Notes:** Created `docs/channel-configuration.md`. Documents all three channels (Telegram, CLI, Cron), their vault interactions, active cron jobs, locking coordination, shared state files, and a compliance matrix confirming all channels follow AGENTS.md.

### MS-008: Git Integration and Commit Workflow
- **Status:** done
- **Priority:** P1
- **Acceptance Criteria:**
  1. Vault is tracked in git at D:\programming\
  2. .gitignore excludes .obsidian/ workspace config (user preference)
  3. Agents commit vault after every significant write
  4. Initial commit with full structure is done
- **Notes:** Depends on MS-001. The initial commit is part of MS-001.
