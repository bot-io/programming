# Supervisor Agent - Automatic Issue Detection and Fixing

## Overview

The **SupervisorAgent** is automatically included in every AI team to monitor work quality and catch issues that we've been fixing manually. It runs continuously in the background, auditing the team's work and automatically fixing problems.

## What It Does

### 1. Monitors Completed Tasks
- ✅ **Validates Artifacts**: Checks that completed tasks actually have their artifacts
- ✅ **Detects Missing Files**: Finds tasks marked complete without creating required files
- ✅ **Catches Premature Completions**: Identifies tasks completed too quickly (likely incomplete)

### 2. Validates Project Structure
- ✅ **Checks Critical Files**: Verifies required files exist (e.g., `pubspec.yaml`, `lib/main.dart` for Flutter)
- ✅ **Validates Expected Files**: Checks that files expected from completed tasks actually exist
- ✅ **Detects Missing Implementations**: Finds placeholder files that should have real code

### 3. Verifies Builds and Executables
- ✅ **Checks Final Verification**: Ensures final verification actually built executables
- ✅ **Validates Build Artifacts**: Verifies build directories and output files exist
- ✅ **Detects Incomplete Builds**: Finds cases where builds were attempted but failed

### 4. Monitors Task Health
- ✅ **Detects Stuck Tasks**: Identifies tasks that have been in progress too long without progress
- ✅ **Tracks Progress**: Monitors if tasks are making real progress or just stuck

## Automatic Fixes

When the supervisor finds issues, it automatically:

### 1. Resets Incomplete Tasks
- **Missing Artifacts**: Resets task to `READY` status so it can be retried
- **No Artifacts**: Resets task if completed without any artifacts
- **Premature Completion**: Resets tasks completed too quickly

### 2. Creates Fix Tasks
- **Missing Files**: Creates fix tasks for missing critical files
- **Build Issues**: Creates build tasks when executables are missing
- **Incomplete Builds**: Creates tasks to complete builds

### 3. Logs Issues
- Tracks all issues found
- Records fixes applied
- Provides supervisor reports

## Integration

The supervisor is **automatically added** to every team in `GenericProjectRunner`:

```python
# In create_agents() - supervisor is always created first
supervisor = SupervisorAgent("supervisor-agent-1", self.coordinator)
self.agents.append(supervisor)
```

No configuration needed - it's part of every team by default.

## Audit Frequency

- **Default**: Every 30 seconds
- **Configurable**: Set `audit_interval` in supervisor initialization
- **Continuous**: Runs in background thread, doesn't block other agents

## Issue Types Detected

### High Severity
- Missing critical files (e.g., `lib/main.dart`, `pubspec.yaml`)
- Tasks completed without artifacts
- Final verification without builds
- Missing expected files from completed tasks

### Medium Severity
- Stuck tasks (in progress > 30 minutes without progress)
- Incomplete builds (build directory exists but no outputs)

### Low Severity
- Tasks completed very quickly (might be legitimate, but flagged for review)

## Example Issues Caught

1. **Task marked complete but file missing**
   - Issue: `implement-ebook-parsing` completed but `lib/services/ebook_parser.dart` doesn't exist
   - Fix: Reset task to `READY` status

2. **Final verification without builds**
   - Issue: `final-verification` completed but no `build/` directory
   - Fix: Create `fix-build-artifacts` task

3. **Premature completion**
   - Issue: Setup task completed in 2 seconds
   - Fix: Reset task to `READY` status

4. **Missing critical files**
   - Issue: Flutter project but `lib/main.dart` missing
   - Fix: Create `fix-missing-lib-main-dart` task

## Supervisor Report

The supervisor provides a report of its activities:

```python
report = supervisor.get_supervisor_report()
# Returns:
# {
#   'last_audit': '2025-12-26T23:00:00',
#   'issues_found': 5,
#   'fixes_applied': 3,
#   'recent_issues': [...],
#   'recent_fixes': [...]
# }
```

## Benefits

1. **Automatic Quality Control**: Catches issues before they become problems
2. **Reduces Manual Intervention**: Fixes issues automatically when possible
3. **Improves Team Reliability**: Ensures tasks are actually completed, not just marked complete
4. **Validates Deliverables**: Ensures builds and executables are actually created
5. **Prevents Stuck Teams**: Detects and helps resolve stuck tasks

## Future Enhancements

- Content validation (check code files have actual implementation, not just TODOs)
- Dependency validation (ensure required dependencies are declared)
- Test coverage validation (ensure tests are meaningful)
- Performance monitoring (track agent efficiency)
- Automatic retry logic for failed tasks

