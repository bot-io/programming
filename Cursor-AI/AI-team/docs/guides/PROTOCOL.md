# AI Agent Team Protocol: Incremental Collaborative Work

## Overview

This protocol defines how multiple AI agents work together on a project, ensuring incremental progress, clear communication, and coordinated task execution.

## Core Principles

1. **Incremental Work**: All tasks are broken down into small, manageable increments
2. **Clear Ownership**: Each task has a single responsible agent
3. **Transparent Communication**: Agents share progress, blockers, and dependencies
4. **Checkpoint-Based Progress**: Regular checkpoints ensure work is saved and validated
5. **Dependency Management**: Agents coordinate when tasks depend on each other

## Protocol Phases

### Phase 1: Task Planning & Decomposition

1. **Task Breakdown**
   - Large tasks are decomposed into increments (typically 1-4 hours of work)
   - Each increment must be:
     - Independently testable/verifiable
     - Clearly defined with acceptance criteria
     - Small enough to complete in one session

2. **Dependency Mapping**
   - Identify task dependencies
   - Create dependency graph
   - Prioritize tasks based on dependencies

3. **Assignment**
   - Assign tasks to agents based on:
     - Agent capabilities/specialization
     - Current workload
     - Dependencies (blocked tasks wait)

### Phase 2: Incremental Execution

1. **Pre-Work Checklist**
   - Agent reviews task requirements
   - Agent checks for dependencies (are prerequisites complete?)
   - Agent confirms understanding with team lead/coordinator

2. **Work Session**
   - Agent acquires locks on resources before modifying them
   - Agent works in isolated workspace (if conflict prevention enabled)
   - Agent creates checkpoints at logical points (every 15-30 minutes)
   - Agent documents decisions and approach
   - Agent releases locks when done with resources

3. **Progress Updates**
   - Agent reports status: `in_progress`, `blocked`, `completed`
   - Agent updates progress percentage (0-100%)
   - Agent flags blockers or dependencies immediately

4. **Completion Criteria**
   - Increment meets acceptance criteria
   - Code/task is tested/validated
   - Changes validated for conflicts
   - All resource locks released
   - Documentation is updated
   - Changes are committed to version control

### Phase 3: Integration & Validation

1. **Checkpoint Review**
   - Completed increment is reviewed
   - Integration with existing work is verified
   - Tests pass (if applicable)

2. **Dependency Unblocking**
   - Agents waiting on this increment are notified
   - Dependent tasks are moved to `ready` status

3. **Continuous Integration**
   - Work is integrated incrementally (not in big batches)
   - Each increment builds on previous work

## Communication Protocol

### Message Types

1. **Status Update**
   ```
   Agent: [agent_id]
   Task: [task_id]
   Status: [in_progress|blocked|completed]
   Progress: [0-100%]
   Message: [optional details]
   ```

2. **Dependency Request**
   ```
   Agent: [agent_id]
   Task: [task_id]
   Type: dependency_request
   Blocked_On: [task_id or agent_id]
   Message: [what is needed]
   ```

3. **Checkpoint**
   ```
   Agent: [agent_id]
   Task: [task_id]
   Type: checkpoint
   Progress: [0-100%]
   Changes: [summary of what was done]
   Next_Steps: [what comes next]
   ```

4. **Completion**
   ```
   Agent: [agent_id]
   Task: [task_id]
   Type: completion
   Result: [summary]
   Artifacts: [files created/modified]
   Tests: [test results if applicable]
   ```

### Communication Channels

- **Task Queue**: Centralized task management
- **Status Board**: Real-time view of all agent statuses
- **Dependency Graph**: Visual representation of task dependencies
- **Checkpoint Log**: Historical record of all checkpoints

## Task States

- `pending`: Task is defined but not started
- `ready`: Dependencies met, ready to start
- `assigned`: Assigned to an agent
- `in_progress`: Agent is actively working
- `blocked`: Waiting on dependency or resource
- `review`: Completed, awaiting review/integration
- `completed`: Fully integrated and validated
- `failed`: Task failed, needs attention

## Incremental Work Guidelines

### What Makes a Good Increment?

1. **Size**: 1-4 hours of focused work
2. **Value**: Delivers tangible progress toward goal
3. **Testability**: Can be verified independently
4. **Isolation**: Minimal coupling with in-progress work
5. **Documentation**: Changes are self-documenting or documented

### Increment Lifecycle

```
[Planning] → [Ready] → [In Progress] → [Checkpoint] → [Review] → [Completed]
                ↓           ↓
            [Blocked]   [Blocked]
```

### Checkpoint Requirements

- Minimum: Every 30 minutes of active work
- Required: Before switching tasks
- Required: When reaching logical milestones
- Required: When blocked or encountering issues

## Conflict Prevention & Resolution

### Resource Locking

1. **Lock Before Modify**: Agents must acquire locks on resources (files, directories) before modifying them
2. **Lock Types**:
   - `EXCLUSIVE`: Only one agent can access (for writes)
   - `SHARED_READ`: Multiple agents can read simultaneously
   - `SHARED_WRITE`: Multiple agents can write with coordination
3. **Lock Timeout**: Locks expire after a set time (default 60 minutes) to prevent deadlocks
4. **Automatic Release**: Locks are released when task completes or agent releases them

### Workspace Isolation

1. **Isolated Workspaces**: Each agent works in its own workspace/branch
2. **Integration Gates**: Changes are validated before integration
3. **Conflict Detection**: System detects file conflicts before integration
4. **Atomic Operations**: Changes can be committed or rolled back atomically

### Conflict Detection

1. **Pre-Integration Validation**: All changes are validated before marking as completed
2. **File Conflict Detection**: System detects when multiple agents modify the same files
3. **Dependency Conflicts**: Detects conflicts with integrated and pending changes
4. **Blocking on Conflicts**: Tasks are blocked if conflicts are detected

### Conflict Resolution Strategies

1. **Resource Conflicts**: First-come-first-served, or coordinator assigns priority
2. **File Conflicts**: 
   - Agents work in isolated workspaces
   - Changes validated before integration
   - Coordinator merges or assigns resolution
3. **Design Conflicts**: Escalate to team lead/coordinator
4. **Dependency Deadlocks**: Coordinator intervenes to break cycles
5. **Rollback**: Atomic operations can be rolled back if conflicts detected

## Best Practices

1. **Start Small**: Begin with smallest viable increment
2. **Lock Resources**: Always acquire locks before modifying files/resources
3. **Work in Isolation**: Use isolated workspaces to prevent conflicts
4. **Validate Early**: Check for conflicts before completing tasks
5. **Communicate Early**: Report blockers immediately
6. **Document Decisions**: Record why, not just what
7. **Test Incrementally**: Verify each increment works
8. **Review Regularly**: Check progress against goals
9. **Adapt Quickly**: Adjust plan based on learnings
10. **Release Locks**: Always release locks when done or on error

## Metrics & Monitoring

- **Throughput**: Increments completed per time period
- **Block Time**: Time tasks spend in blocked state
- **Cycle Time**: Time from ready to completed
- **Dependency Wait**: Time waiting on dependencies
- **Checkpoint Frequency**: How often agents checkpoint

## Example Workflow

```
1. Team Lead: "Build user authentication system"
   
2. Coordinator: Decomposes into increments:
   - Increment 1: Database schema for users (2h)
   - Increment 2: Registration API endpoint (2h)
   - Increment 3: Login API endpoint (2h)
   - Increment 4: JWT token generation (2h)
   - Increment 5: Password hashing (1h)
   
3. Agent A: Takes Increment 1, works, checkpoints, completes
   
4. Agent B: Takes Increment 5 (no dependencies), works in parallel
   
5. Agent C: Waits for Increment 1, then takes Increment 2
   
6. Agent D: Waits for Increments 1 & 5, then takes Increment 3
   
7. Agent E: Waits for Increments 2 & 3, then takes Increment 4
   
8. All increments integrated incrementally, system works end-to-end
```

