# Supervisor Issues Checklist and Log

This document defines all issues that the supervisor must monitor, detect, and fix during team operation. The supervisor must continuously check for these issues and log all findings in this file. The supervisor must only add issues that are not already present in this file.

## Global Metrics and Standards

The following metrics define the expected behavior of the AI team. All issues must be evaluated against these standards:

### Progress Update Frequency
- **Standard**: If progress is less than 100%, the last updated time must be within the last 2 minutes
- **Stuck Threshold**: If the last overall progress update was older than 10 minutes, the team is considered stuck
- **Reference**: Used to detect progress stagnation issues

### Tasks in Progress Requirement
- **Standard**: When the project is incomplete (progress < 100%), there must be tasks in progress unless all ready tasks are blocked or there are no ready tasks available
- **Exception**: If all ready tasks are blocked or there are no ready tasks, having 0 tasks in progress is acceptable
- **Reference**: Used to detect task assignment and state transition issues

### Progress History Integrity
- **Standard**: Completed task count must never go backwards
- **Standard**: Progress history must show incremental progress
- **Reference**: Used to detect data persistence and progress tracking issues

### Task State Transition Timeframes
- **Standard**: Tasks should transition from PENDING to READY within 1 minute if dependencies are met
- **Standard**: Tasks should transition from BLOCKED to READY within 1 minute when dependencies complete
- **Standard**: Ready tasks should be assigned within 2 minutes of becoming ready
- **Reference**: Used to detect task state transition issues

### Dependency Resolution
- **Standard**: Tasks with no dependencies (empty list) must transition from PENDING to READY immediately
- **Standard**: Tasks with all dependencies completed must transition from BLOCKED/PENDING to READY within 1 minute
- **Reference**: Used to detect dependency management issues

## Issue Categories

### 1. Progress Stagnation Issues

#### 1.1 Overall Progress Stagnation
- **Description**: Progress not updating within expected timeframes
- **Detection**: Violates **Global Metric: Progress Update Frequency** - If progress is less than 100%, the last updated time must be within the last 2 minutes. If the last overall progress was older than 10 minutes, the team is stuck.
- **Fix**: Investigate why progress is not updating, check for errors in the main loop, verify progress persistence is working.

#### 1.2 Progress History Anomalies
- **Description**: Completed task count going backwards, no incremental progress
- **Detection**: Violates **Global Metric: Progress History Integrity** - Completed task count must never go backwards, progress history must show incremental progress
- **Fix**:
  * Verify task completion logic and persistence (coordinator must reject COMPLETED → non-COMPLETED transitions).
  * Ensure the **Supervisor never resets COMPLETED tasks** (e.g., “incorrectly completed” remediations must create fix-up tasks instead of flipping status back to READY/PENDING).
  * Check for race conditions in progress tracking.

### 2. Task State Transition Issues

#### 2.1 Blocked Tasks Not Unblocking
- **Description**: Tasks blocked when dependencies are completed
- **Detection**: Check if blocked tasks have dependencies that are completed
- **Checks Required**:
  * Do blocked tasks have dependencies? Are those dependencies completed?
  * Are blocked tasks being checked for unblocking in the main loop?
  * Are dependency completion events triggering unblock checks?
  * Are there tasks blocked by DEPENDENCY_REQUEST that don't have dependencies tracked?
  * Check logs for "Task X is now READY" or "Task X is now BLOCKED" messages to verify unblocking logic is working
- **Fix**: Ensure `_update_task_status` is called for all blocked tasks when dependencies complete, verify dependency resolution logic.

#### 2.2 Ready Tasks Not Being Assigned
- **Description**: Ready tasks available but agents not picking them up
- **Detection**: Violates **Global Metric: Tasks in Progress Requirement** - When project is incomplete, there must be tasks in progress unless all ready tasks are blocked. Also violates **Global Metric: Task State Transition Timeframes** - Ready tasks should be assigned within 2 minutes.
- **Checks Required**:
  * Are agents requesting tasks?
  * Are ready tasks visible to agents (check get_ready_tasks())?
  * Are there conflicts preventing assignment?
  * Are agents running and in the correct state?
  * Check logs for task assignment attempts and failures
- **Fix**: Verify agent task request logic, check conflict prevention system, ensure agents are in correct state.

#### 2.3 PENDING Tasks Not Transitioning to READY
- **Description**: Tasks with no dependencies stuck in PENDING state
- **Detection**: Violates **Global Metric: Dependency Resolution** - Tasks with no dependencies must transition from PENDING to READY immediately. Also violates **Global Metric: Task State Transition Timeframes** - Tasks should transition from PENDING to READY within 1 minute if dependencies are met.
- **Fix**: Ensure `_update_task_status` is called for all PENDING tasks, verify dependency parsing.

#### 2.4 BLOCKED Tasks Not Transitioning to READY
- **Description**: Tasks with completed dependencies stuck in BLOCKED state
- **Detection**: Violates **Global Metric: Dependency Resolution** - Tasks with all dependencies completed must transition from BLOCKED to READY within 1 minute. Also violates **Global Metric: Task State Transition Timeframes**.
- **Fix**: Verify dependency completion check logic, ensure REVIEW status is treated as completed.

#### 2.6 BLOCKED Tasks Auto-Unblocking Despite Non-Dependency Blockers (Retry Loop)
- **Description**: A task becomes BLOCKED for a non-dependency reason (e.g., acceptance/tooling/environment failure), but the coordinator unblocks it anyway just because dependencies are met. This causes infinite READY → IN_PROGRESS → BLOCKED loops without real progress.
- **Detection**:
  * Dependencies are satisfied, but the task repeatedly cycles between READY/IN_PROGRESS/BLOCKED.
  * BLOCKED reason/messages repeat across cycles (same acceptance failure or environment/tooling error).
  * Coordinator logs show frequent "unblocked: BLOCKED -> READY" for the same task without any new dependency completion.
- **Fix**:
  * Preserve a task's non-dependency blocker reason/message when marking it BLOCKED.
  * Only auto-unblock BLOCKED tasks when the block reason is dependency-related; keep other blocks BLOCKED until the blocker is resolved or the task definition is updated.

#### 2.5 Tasks Stuck in Intermediate States
- **Description**: Tasks stuck in ASSIGNED or IN_PROGRESS without progress
- **Detection**: Tasks in ASSIGNED or IN_PROGRESS state for extended periods without updates
- **Fix**: Check agent state, verify task assignment logic, ensure agents are processing tasks.

### 3. Dependency Management Issues

#### 3.1 Dependency Parsing Issues
- **Description**: "Dependencies: none" parsed incorrectly as ["none"] instead of empty list
- **Detection**: Violates **Global Metric: Dependency Resolution** - Tasks with no dependencies (empty list) must transition from PENDING to READY immediately, but parsing errors prevent this.
- **Fix**: Verify task config parser correctly handles "none", "no dependencies", "no deps", "n/a" keywords.

#### 3.2 Missing Dependencies
- **Description**: Tasks referencing dependencies that don't exist
- **Detection**: Check for tasks with dependencies not in the task list
- **Fix**: Add missing dependencies or remove invalid references.

#### 3.3 Circular Dependencies
- **Description**: Tasks forming dependency cycles
- **Detection**: Check dependency graph for cycles
- **Fix**: Break circular dependencies by restructuring tasks.

#### 3.4 Dependency Field Contamination (Section Markers Parsed as Dependencies)
- **Description**: Non-dependency section markers or bullet lines (e.g., "Acceptance Criteria", "Artifacts", "Task completes successfully") are incorrectly parsed into a task's dependency list, causing false "missing dependencies" deadlocks.
- **Detection**:
  * In `tasks.md` (or progress reports derived from it), `Dependencies:` contains tokens that are not task IDs (e.g., `- Acceptance Criteria:`).
  * Coordinator reports `Missing dependencies: ['- Acceptance Criteria:', ...]` or similar.
- **Fix**: Harden task parser field-boundary detection; ensure dependencies only accept valid task IDs; add validator coverage for this corruption pattern.

### 4. Agent State Issues

#### 4.1 Agents Not Requesting Tasks
- **Description**: Agents idle but not requesting tasks
- **Detection**: Agents in IDLE state but not calling request_task()
- **Fix**: Check agent run loop, verify agent state machine transitions.

#### 4.2 Agents in Incorrect States
- **Description**: Agents in unexpected states (ERROR, STOPPED when should be RUNNING)
- **Detection**: Monitor agent states, check for unexpected transitions
- **Fix**: Reset agent state, investigate root cause of state issues.

### 5. Data Persistence Issues

#### 5.1 Missing or Incorrect Task Status Updates
- **Description**: Task status changes not persisted to tasks.md
- **Detection**: Coordinator state differs from tasks.md
- **Fix**: Ensure `update_task_in_file` is called after status changes, verify file write operations.

#### 5.2 Progress Report Not Created or Updated
- **Description**: Progress report missing or not updating
- **Detection**: Progress report file missing or last updated time stale
- **Fix**: Verify progress persistence is working, check for errors in save_progress().

#### 5.3 Initialization Log Missing or Incomplete
- **Description**: Team initialization log missing, never created, or only contains "started" without a corresponding "completed" entry
- **Detection**:
  * Check for `agent_logs/team_initialization.log`
  * Verify the file contains both "Team initialization started" and "Team initialization completed"
  * If only "started" exists, initialization likely hung or crashed
- **Fix**: Ensure initialization log is created immediately at `run()` start (before other init), add crash-safe flush, and add error logging around initialization steps.

### 6. System Configuration Issues

#### 6.1 Team ID Not Present
- **Description**: Team ID missing from logs or progress reports
- **Detection**: Check logs and progress reports for team ID presence
- **Fix**: Ensure team ID is generated at initialization and included in all outputs.

#### 6.2 Multiple Teams Running
- **Description**: Multiple team instances running on the same project
- **Detection**: Check for multiple .team_id files or processes
- **Fix**: Stop duplicate teams, ensure only one team instance per project.

#### 6.3 Team Process Not Running (Stopped / Crashed)
- **Description**: Team is expected to be running but there is no active `run_team.py` process, causing progress/logs to go stale
- **Detection**:
  * Progress report becomes stale (> 2 minutes while progress < 100%)
  * No active `run_team.py` process for the project directory
  * `.team_id` exists but no running process (stale team instance)
- **Fix**: Restart the team, then investigate crash cause via logs. Add guard rails so stale `.team_id` cannot be mistaken for a running team.

### 7. Conflict Prevention Issues

#### 7.1 False Conflicts Preventing Assignment
- **Description**: Tasks not being assigned due to incorrect conflict detection
- **Detection**: Ready tasks not assigned despite no actual conflicts
- **Fix**: Verify conflict detection logic, check resource locking system.

### 8. Issue Discovery Process

When progress stalls or tasks remain in non-terminal states (BLOCKED, READY, PENDING), investigate systematically:

1. Read the progress report to identify stuck tasks and their states
2. Check agent logs for errors, warnings, or unusual patterns
3. Check coordinator logs for task state transitions
4. Verify the expected state machine transitions are implemented correctly
5. Check if state update methods are being called (add logging if needed)
6. Verify state persistence (tasks.md updates) is working
7. Check for race conditions or timing issues
8. Verify all code paths that should trigger state changes are actually executing
9. Verify dependency parsing - check if "Dependencies: none" is correctly parsed as empty list (not ["none"])
10. Check if tasks with no dependencies are correctly identified and transitioned to READY

### 9. Deliverable / Requirements Verification Issues

#### 9.1 Progress Says Complete But Deliverable Is Still a Template / Missing Required Artifacts
- **Description**: Progress report indicates 100% completion, but the actual deliverable is still the framework template (e.g., default demo) or required artifacts referenced by `requirements.md` are missing.
- **Detection**:
  * When **Overall Progress = 100%**, verify the project output is not a default scaffold/template (framework-specific templates are acceptable to detect when they are clearly unmodified).
  * Verify key artifacts referenced in `requirements.md` exist (e.g., explicitly referenced file paths like `lib/...`).
  * Verify key dependencies referenced in `requirements.md` are present in dependency manifests (e.g., Flutter `pubspec.yaml`).
- **Fix**:
  * Prevent false completion by requiring artifact existence checks before allowing task completion.
  * Add/strengthen automated validation checks (prefer requirements-driven checks over project-specific hardcoding).
  * Reset incorrectly completed tasks and re-run until deliverable matches requirements.

### 9. Fixing Issues

When issues are detected:

- Fix issues in a generic way in the generic implementation
- Add comprehensive logging to track state transitions and identify where the flow breaks
- Ensure fixes handle edge cases (missing dependencies, malformed data, etc.)
- Test fixes by checking logs for expected behavior
- Update requirements if new patterns are discovered
- The same issues should not happen again - if they do, the logging should reveal why
- Persist fixes to tasks.md and other relevant files when correcting task states

## Supervisor Responsibilities

The supervisor must:

1. **Continuously Monitor**: Check for all issues listed in this document during team operation
2. **Detect Issues**: Identify when any of these issues occur
3. **Fix Issues**: Apply generic fixes when possible
4. **Log Issues**: Record all detected issues in this same file (`supervisor_issues_checklist.md`) in the parent directory (single-file log; no duplicates)
5. **Prevent Recurrence**: Add logging and safeguards to prevent the same issues from happening again

## Issue Logging Format

Each issue logged in this file must be a high-level description only. The supervisor must add detected issues to the "Issues Detected" section below. The supervisor must check if an issue already exists before adding it to prevent duplicates.

## Detected Issues Log

The supervisor must add detected issues to this section below. Each issue should be a simple, high-level description without detailed IDs, timestamps, or fix information.

---

### Issues Detected

- Progress not updating (violates Progress Update Frequency metric - must update within 2 minutes, stuck if > 10 minutes)
- No tasks in progress while ready tasks available (violates Tasks in Progress Requirement metric)
- Agent execution errors due to logging import/scoping issues (e.g., `AgentLogger` UnboundLocalError) causing tasks to fail and progress to stall
- Acceptance criteria command failures (invalid CLI invocation / incorrect parameters) can stall tasks and block dependency chains
- Acceptance criteria parsing can misclassify inline backticked config/code snippets (e.g., `hive: ^x.y.z`, `minSdkVersion 21`) as runnable shell commands, causing false failures and deadlocks
- Non-dependency BLOCKED tasks can be incorrectly auto-unblocked (deps met) causing infinite retry loops (READY → IN_PROGRESS → BLOCKED)
- Supervisor remediations must never reset COMPLETED tasks (must keep completed-count monotonic); if artifacts are missing after “completion”, create fix-up tasks instead of flipping status back to READY/PENDING
- Progress can report 100% while deliverable remains a default template / required artifacts are missing
- Task parsing can mis-handle field boundaries (e.g., treating “Acceptance Criteria” bullets as dependencies/artifacts), causing false missing-dependency deadlocks
- Target-file inference can miss common config file extensions (e.g., `.gradle`), causing execution to fail with “No target files inferred”
- Completed tasks not being marked as integrated in the conflict-prevention system can cause false “pending task” conflicts that deadlock downstream tasks
- Artifact/path normalization that strips leading dot (`.`) can break validation for hidden directories/files (e.g., `.dart_tool/`), causing false “missing artifacts” blockers
- Agent executors can accidentally run in per-task workspace CWD instead of the project root (e.g., using `os.getcwd()`), causing created files/dirs to land in the wrong place and completion validation to fail

- Failed tasks blocking progress (violates Tasks in Progress Requirement metric)

## Validation Command (Run This To Check All Issues)

This command runs a single validator that checks the project directory against **all issue categories and global metrics** in this checklist and prints PASS/FAIL per issue.

- **Command**:

```bash
python scripts/validate_supervisor_issues.py --project-dir test_notes_app
```

- **Notes**:
  * Use any project directory that contains `requirements.md` (and typically `tasks.md`, `progress_reports/`, `agent_logs/`).
  * The validator is intentionally generic (no project-specific assumptions).

