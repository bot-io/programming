# Conflict Prevention Guide

## Overview

This guide explains how the conflict prevention system ensures agents can work together without interfering with each other's progress.

## Key Mechanisms

### 1. Resource Locking

**Purpose**: Prevent multiple agents from modifying the same files simultaneously.

**How it works**:
- Agents request locks before modifying resources
- Locks are exclusive by default (only one agent can modify)
- Locks expire after timeout to prevent deadlocks
- Locks are automatically released when tasks complete

**Example**:
```python
# Agent requests lock before modifying file
if agent.request_resource_lock("src/api/users.py"):
    # Safe to modify file
    modify_file("src/api/users.py")
    agent.release_resource_lock("src/api/users.py")
else:
    # File is locked by another agent
    agent.report_blocked(task_id, "File locked by another agent")
```

### 2. Workspace Isolation

**Purpose**: Each agent works in its own isolated workspace to prevent conflicts.

**How it works**:
- Coordinator creates isolated workspace for each agent/task
- Agents work in their workspace without affecting others
- Changes are integrated only after validation
- Workspaces are cleaned up after task completion

**Benefits**:
- Agents can work in parallel without conflicts
- Changes are validated before integration
- Easy rollback if issues detected

### 3. Conflict Detection

**Purpose**: Detect conflicts before integrating changes.

**How it works**:
- System tracks all file changes by agents
- Before integration, checks for file conflicts
- Compares against both integrated and pending changes
- Blocks integration if conflicts detected

**Example**:
```python
# Before completing task, validate changes
is_valid, issues = agent.validate_changes(
    files_modified=["src/api/users.py"],
    files_created=["src/models/user.py"]
)

if not is_valid:
    # Conflicts detected, task is blocked
    print(f"Conflicts: {issues}")
else:
    # Safe to integrate
    agent.complete_task(task_id, "Task completed", artifacts=files)
```

### 4. Atomic Operations

**Purpose**: Ensure changes are applied atomically (all or nothing).

**How it works**:
- Operations are tracked with rollback information
- Changes can be committed or rolled back
- Prevents partial integrations that could break the system

**Example**:
```python
# Start atomic operation
op_id = coordinator.conflict_prevention.start_atomic_operation(
    agent_id, "Update user API"
)

# Make changes
# ... modify files ...

# Commit or rollback
if validation_passes:
    coordinator.conflict_prevention.commit_atomic_operation(op_id)
else:
    coordinator.conflict_prevention.rollback_atomic_operation(op_id)
```

## Usage Patterns

### Pattern 1: Safe File Modification

```python
class SafeAgent(Agent):
    def work(self, task: Task) -> bool:
        files_to_modify = ["src/api/users.py", "src/models/user.py"]
        
        # Acquire locks on all files
        all_locked = True
        for file in files_to_modify:
            if not self.request_resource_lock(file):
                # Couldn't acquire lock, release what we got
                self.release_all_locks()
                self.report_blocked(
                    task.id,
                    f"File {file} is locked by another agent"
                )
                return False
        
        try:
            # Now safe to modify files
            for file in files_to_modify:
                modify_file(file)
            
            # Validate changes before completion
            is_valid, issues = self.validate_changes(files_to_modify)
            if not is_valid:
                return False
            
            # Complete task
            self.complete_task(
                task.id,
                "Files modified successfully",
                artifacts=files_to_modify
            )
            return True
        finally:
            # Always release locks
            self.release_all_locks()
```

### Pattern 2: Parallel Work with Shared Resources

```python
# Agent 1: Reads shared config
if agent1.request_resource_lock("config.json", LockType.SHARED_READ):
    config = read_config("config.json")
    # Multiple agents can read simultaneously
    agent1.release_resource_lock("config.json")

# Agent 2: Also reads (shared read lock allows this)
if agent2.request_resource_lock("config.json", LockType.SHARED_READ):
    config = read_config("config.json")
    agent2.release_resource_lock("config.json")

# Agent 3: Wants to modify (needs exclusive lock)
if agent3.request_resource_lock("config.json", LockType.EXCLUSIVE):
    # Only one agent can modify
    modify_config("config.json")
    agent3.release_resource_lock("config.json")
```

### Pattern 3: Conflict-Aware Task Completion

```python
def complete_task_safely(self, task: Task, artifacts: List[str]):
    # Validate changes first
    is_valid, issues = self.validate_changes(artifacts)
    
    if not is_valid:
        # Conflicts detected
        self.send_status_update(
            task.id,
            TaskStatus.BLOCKED,
            message=f"Cannot complete: {', '.join(issues)}"
        )
        return False
    
    # No conflicts, safe to complete
    return self.complete_task(
        task.id,
        "Task completed successfully",
        artifacts=artifacts
    )
```

## Lock Types

### EXCLUSIVE
- Only one agent can hold the lock
- Used for write operations
- Prevents any concurrent access

### SHARED_READ
- Multiple agents can hold the lock simultaneously
- Used for read-only operations
- Allows parallel reading

### SHARED_WRITE
- Multiple agents can hold the lock
- Requires coordination between agents
- Used for coordinated writes

## Best Practices

1. **Lock Early**: Acquire locks as soon as you know which files you'll modify
2. **Lock Minimally**: Only lock files you actually need to modify
3. **Release Promptly**: Release locks as soon as you're done with a file
4. **Handle Failures**: Always release locks in finally blocks or on errors
5. **Validate Before Complete**: Always validate changes before completing tasks
6. **Use Workspaces**: Work in isolated workspaces when possible
7. **Check Conflicts**: Use conflict detection before integration
8. **Atomic Operations**: Use atomic operations for multi-file changes

## Common Issues and Solutions

### Issue: Lock Timeout
**Problem**: Lock expires while agent is still working
**Solution**: Extend lock periodically or increase timeout

### Issue: Deadlock
**Problem**: Two agents waiting for each other's locks
**Solution**: Locks expire automatically, or coordinator can break deadlocks

### Issue: False Conflicts
**Problem**: System detects conflicts that aren't real
**Solution**: Use workspace isolation or adjust conflict detection logic

### Issue: Lock Not Released
**Problem**: Agent crashes without releasing lock
**Solution**: Locks expire automatically after timeout

## Monitoring

Check conflict prevention status:

```python
status = coordinator.conflict_prevention.get_status()
print(f"Active locks: {status['locks']['total_locks']}")
print(f"Pending changes: {status['pending_changes']}")
print(f"Integrated changes: {status['integrated_changes']}")
```

## Integration with Version Control

For real projects, integrate with Git:

1. Each agent works in a separate branch
2. Locks prevent concurrent modifications
3. Changes are validated before merge
4. Merge conflicts are detected early

Example Git integration:
```python
def work_with_git(self, task: Task):
    # Create branch
    branch_name = f"agent-{self.agent_id}-task-{task.id}"
    create_branch(branch_name)
    
    # Work in branch (isolated)
    # ... make changes ...
    
    # Validate before merge
    if self.validate_changes(files):
        # Merge to main
        merge_to_main(branch_name)
        self.complete_task(task.id, "Merged successfully", artifacts=files)
```

