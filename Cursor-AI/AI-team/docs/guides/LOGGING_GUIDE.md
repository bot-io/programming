# Team Logging Guide

## Overview

All team members now have comprehensive logging enabled. Logs are stored in `agent_logs/` directory and include detailed information for diagnosing issues.

## Log Locations

- **Developer Agent**: `agent_logs/developer-agent-1.log`
- **Supervisor Agent**: `agent_logs/supervisor-agent-1.log`
- **Tester Agent**: `agent_logs/tester-agent-1.log`
- **Cursor CLI**: Logged under agent IDs (e.g., `CURSOR_CLI` entries in developer logs)

## Log Format

Each log entry follows this format:
```
[YYYY-MM-DD HH:MM:SS.mmm] [LEVEL] [AGENT_ID] [task:TASK_ID] Message | extra=data
```

## Key Log Levels

- **DEBUG**: Detailed diagnostic information
- **INFO**: General informational messages
- **WARNING**: Warning conditions
- **ERROR**: Error conditions
- **CRITICAL**: Critical failures
- **TASK_START**: Task started
- **TASK_COMPLETE**: Task completed
- **TASK_FAIL**: Task failed
- **METHOD_ENTRY/EXIT**: Method entry/exit for tracing execution flow
- **FLOW**: Execution flow steps

## What's Logged

### Cursor CLI Client
- CLI verification (success/failure, timing)
- All command executions (command, role, working directory)
- Response handling (length, timing, preview)
- Error details (exit codes, stderr, stack traces)
- PATH configuration (ripgrep detection)

### Developer Agent
- Work method entry/exit with full task context
- Code generation steps:
  - Prompt and context lengths
  - File paths being generated
  - Timing for each step
- File operations:
  - File creation/modification
  - File sizes
  - Paths
- Task completion/failure:
  - Artifact counts
  - Elapsed time
  - Success/failure reasons

### Supervisor Agent
- Audit cycles:
  - Timing for each audit
  - Issue counts and types
  - Task counts
- Issue detection:
  - Issue types
  - Severity levels
  - Full issue details
- Fixes applied:
  - What was fixed
  - Timing
  - Results
- Task generation:
  - Requirements file size
  - Tasks generated count
  - Timing

## Using Logs to Diagnose Issues

### 1. Check if Cursor CLI is Working

```powershell
# Look for CLI verification and execution logs
Select-String -Path "agent_logs\developer-agent-1.log" -Pattern "CURSOR_CLI.*available|CURSOR_CLI.*Executing|CURSOR_CLI.*error"
```

**What to look for:**
- `Cursor CLI is available` - CLI is working
- `Cursor CLI error` - CLI is failing
- `exit_code` in extra data - non-zero means failure
- `stderr` in extra data - error messages

### 2. Check if Code Generation is Working

```powershell
# Look for code generation logs
Select-String -Path "agent_logs\developer-agent-1.log" -Pattern "Received response|Successfully generated|failed to generate"
```

**What to look for:**
- `response_length` - should be > 1000 for real code
- `file_size` - should be > 0 if file was created
- `elapsed` - timing information
- Error messages in `exception` or `traceback` fields

### 3. Check for Stuck Tasks

```powershell
# Look for stuck task detection
Select-String -Path "agent_logs\supervisor-agent-1.log" -Pattern "stuck|0% progress|elapsed"
```

**What to look for:**
- `stuck_task` issue type
- `elapsed` time > 3 minutes
- `progress: 0` for long-running tasks

### 4. Check Task Generation

```powershell
# Look for task generation logs
Select-String -Path "agent_logs\supervisor-agent-1.log" -Pattern "Generating tasks|tasks_generated|template tasks"
```

**What to look for:**
- `tasks_generated` count - should be > 20
- `elapsed` time for generation
- Error messages if generation failed

### 5. Check for Errors

```powershell
# Find all errors
Select-String -Path "agent_logs\*.log" -Pattern "\[ERROR\]|\[CRITICAL\]" | Select-Object -Last 20
```

**What to look for:**
- `exception_type` - type of exception
- `traceback` - full stack trace
- `elapsed` - when error occurred
- Context in `extra` data

## Common Issues and Log Patterns

### Issue: Cursor CLI Not Working
**Log Pattern:**
```
[CURSOR_CLI] ERROR: cursor-agent CLI not found
[CURSOR_CLI] WARNING: Could not verify CLI
```
**Fix:** Check PATH, install Cursor CLI, verify ripgrep is installed

### Issue: Code Generation Failing
**Log Pattern:**
```
[CURSOR_CLI] Cursor CLI returned empty response
[CURSOR_CLI] response contains error indicators
exception_type=RuntimeError
```
**Fix:** Check CLI error details in `stderr` field, verify ripgrep in PATH

### Issue: Tasks Stuck
**Log Pattern:**
```
[FIX] Fixing issue: stuck_task
elapsed > 180 (3 minutes)
progress: 0
```
**Fix:** Supervisor should auto-reset, check if reset happened

### Issue: No Progress
**Log Pattern:**
```
No tasks available
tasks_generated: 0
template tasks detected
```
**Fix:** Check if supervisor generated tasks, verify requirements.md exists

## Log Analysis Commands

### Find All Errors in Last Hour
```powershell
Get-ChildItem agent_logs\*.log | ForEach-Object {
    Get-Content $_.FullName | Select-String -Pattern "\[ERROR\]" | Select-Object -Last 10
}
```

### Check Task Completion Times
```powershell
Select-String -Path "agent_logs\developer-agent-1.log" -Pattern "TASK_COMPLETE" | 
    ForEach-Object { 
        if ($_.Line -match "elapsed=([\d.]+)") { 
            [PSCustomObject]@{ Time = $_.Line.Split(']')[0]; Elapsed = $matches[1] } 
        } 
    }
```

### Monitor Cursor CLI Performance
```powershell
Select-String -Path "agent_logs\*.log" -Pattern "CURSOR_CLI.*elapsed" | 
    ForEach-Object { 
        if ($_.Line -match "elapsed=([\d.]+)") { 
            [PSCustomObject]@{ Elapsed = [double]$matches[1] } 
        } 
    } | Measure-Object -Property Elapsed -Average -Maximum -Minimum
```

## Best Practices

1. **Check logs first** before asking for help
2. **Look for timing patterns** - slow operations indicate issues
3. **Check error context** - `extra` data contains valuable debugging info
4. **Monitor supervisor audits** - they catch most issues automatically
5. **Use structured search** - search by log level, agent ID, or task ID

## Log Retention

Logs are appended to files and not automatically rotated. For long-running teams, consider:
- Archiving old logs periodically
- Using log rotation if needed
- Clearing logs when starting fresh (use `AgentLogger.clear_log()`)

