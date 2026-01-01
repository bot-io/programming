## Goal
Redesign the **generic** AI Team so it proactively avoids the issues in `supervisor_issues_checklist.md`, and when they occur, it **auto-detects + auto-remediates** them using a supervisor control-plane that can create tasks, stop/restart/spawn agents, and keep progress/logging consistent.

This plan is implementation-focused and intentionally project-agnostic: it must work for **any** project directory driven by `requirements.md` + `tasks.md`.

## Architecture (Target State)
- **Workers (independent agents)**: Execute tasks from high-level descriptions using adapters/tools; report progress and artifacts; never mutate other agents’ state directly.
- **Coordinator (scheduler + state machine)**: Owns task state transitions, dependency resolution, conflict prevention, and agent lifecycle registry.
- **Supervisor (control plane)**: Observes metrics/logs/state and applies *policy-driven* remediation:
  - Create/modify tasks (generic “investigation / environment provisioning / verification” tasks)
  - Stop/pause/resume/replace agents
  - Quarantine flapping tasks
  - Enforce “no false completion” gates

## Redesign Requirements Mapped to Checklist

### 1) Progress stagnation (1.1, 1.2)
- **Prevention**:
  - Maintain *agent heartbeats* (in-memory) and persist “last meaningful progress” timestamps.
  - Track “overall progress change” separately from “last updated”.
- **Remediation**:
  - If overall progress isn’t changing while tasks are cycling: detect *flapping* and quarantine the flapping tasks.
  - If overall progress isn’t changing and agents aren’t heartbeating: stop/replace agents; requeue their tasks.

### 2) Task state transition issues (2.1–2.6)
- **Prevention**:
  - Preserve blocker reasons for non-dependency blocks; do not auto-unblock those (prevents READY↔BLOCKED loops).
  - Make assignment decisions observable (why a task is/ isn’t assignable).
  - Ensure resume semantics after restarts for ASSIGNED/IN_PROGRESS tasks.
- **Remediation**:
  - Detect:
    - “Ready but unassigned”
    - “Assigned to stopped agent”
    - “Stuck assigned/in-progress”
    - “Flapping between READY/IN_PROGRESS/BLOCKED”
  - Fix:
    - Requeue task (READY) + clear invalid assignment
    - Stop/replace unresponsive agents
    - Quarantine repeated non-actionable tasks with stable blocker reason

### 3) Dependency management (3.1–3.3)
- **Prevention**:
  - Normalize dependency parsing (already handles “none”).
  - Validate dependency graph on load (missing deps / circular deps).
- **Remediation**:
  - Auto-create missing dependency placeholder tasks when safe, or convert to supervisor issue requiring human input.

### 4) Agent state issues (4.1–4.2)
- **Prevention**:
  - Heartbeats and “idle reason” reporting (no ready tasks vs blocked vs conflict).
- **Remediation**:
  - If agent stops heartbeating: stop/replace agent.
  - If agent is alive but never requests tasks: restart agent loop.
  - Supervisor can *spawn* additional agents when parallelism is available (integrate `AgentManager`/spawning into supervisor policy).

### 5) Data persistence issues (5.1–5.3)
- **Prevention**:
  - Persist task updates on all supervisor/coordinator state changes.
  - Crash-safe init logging.
- **Remediation**:
  - Supervisor reconciles `tasks.md` vs in-memory tasks and fixes drift.

### 6) System configuration (6.1–6.3)
- **Prevention**:
  - Single-team enforcement using Team ID.
  - Detect duplicate `run_team.py` processes for same project and stop extras.
- **Remediation**:
  - Auto-restart when the process dies (supervisor can request restart; runner can also self-recover).

### 9) Deliverable verification (9.1)
- **Prevention**:
  - “No false completion” gate: completion requires artifacts + acceptance checks that are requirements-driven.
- **Remediation**:
  - Reset incorrectly completed tasks; create explicit “verification/build” tasks.

## Implementation Steps (This Rollout)
- Add coordinator-level **agent heartbeat tracking**.
- Add supervisor checks + remediation:
  - Detect unresponsive agents (stale heartbeat) and replace them generically.
  - Detect task flapping and quarantine/hold tasks to prevent infinite loops.
- Wire agent spawning in a project-agnostic way (clone an existing agent class for a specialization; avoid hardcoding project logic).
- Keep validator + checklist aligned; extend validator checks only when needed to reflect new states.

## Non-Goals (for now)
- Perfect semantic understanding of “optional” vs “required” tasks from arbitrary text.
- Project-specific environment installation automation (we can create tasks for it, but can’t guarantee toolchains exist).


