# AI Team Implementation Requirements

## Document Purpose

This document defines the comprehensive requirements for the AI Agent Team system - a protocol and implementation for coordinating multiple AI agents to work together incrementally on software projects.

### Normative Language and Testability
- **MUST**: mandatory behavior for a compliant implementation.
- **SHOULD**: recommended behavior; deviations must be justified.
- **MAY**: optional behavior.
- Unless otherwise stated, each requirement SHOULD be testable via at least one of:
  - **Inspection** (static review of config/files/logs),
  - **Execution** (running the team and observing behavior),
  - **Simulation** (unit/integration tests).

## 1. System Overview

### 1.1 Purpose
The AI Agent Team system enables multiple AI agents to collaborate on software development projects by:
- Breaking work into small, manageable increments (1-4 hours)
- Managing task dependencies and coordination
- Tracking progress with checkpoints
- Enabling parallel work where possible
- Ensuring incremental integration
- Preventing conflicts between agents

### 1.2 Team Identification
- **REQ-1.2.1**: Each AI team instance must have a unique team ID
- **REQ-1.2.2**: Team ID must be generated at team initialization and persist for the entire team lifecycle
- **REQ-1.2.3**: Team ID must be included in all log entries across all agents and system components
- **REQ-1.2.4**: Team ID must be included in all progress reports
- **REQ-1.2.5**: Team ID must be used for team implementation validation and debugging
- **REQ-1.2.6**: Team ID format should be human-readable and include timestamp or unique identifier (e.g., `team-20240101-abc123` or UUID)
  - **Verification (Execution/Inspection)**:
    - Start a new run and confirm a team ID is persisted (e.g., `.team_id` in the project directory or equivalent persistence mechanism).
    - Confirm agent logs include the team ID from the very first emitted log line.
    - Confirm the progress report includes the team ID in its header.

### 1.3 Core Principles
1. **Incremental Work**: All tasks broken into small, manageable increments
2. **Clear Ownership**: Each task has a single responsible agent
3. **Transparent Communication**: Agents share progress, blockers, and dependencies
4. **Checkpoint-Based Progress**: Regular checkpoints ensure work is saved and validated
5. **Dependency Management**: Agents coordinate when tasks depend on each other
6. **Conflict Prevention**: Resource locking and workspace isolation prevent conflicts
7. **Task-Agnostic Design**: Works with any task type through adapters
8. **Configuration-Driven**: Project-agnostic, driven primarily by `requirements.md` (secondary validation allowed; no project-specific hardcoding)
9. **Requirements-Driven**: System relies primarily on `requirements.md` for project type detection, team sizing, and task generation (with optional secondary validation from workspace signals)
10. **Generic Agents**: Uses generic agents that work with any project type by analyzing requirements

## 2. Architecture Requirements

### 2.1 Core Components

#### 2.1.1 AgentCoordinator
**Location**: `src/ai_team/agents/agent_coordinator.py`

**Requirements**:
- Must manage all agents and tasks in the system
- Must handle task assignment based on dependencies and agent availability
- Must process agent messages (status updates, checkpoints, completions)
- Must track progress and checkpoints for all tasks
- Must integrate with conflict prevention system
- Must support task state management (pending, ready, assigned, in_progress, blocked, review, completed, failed)
- Must support dependency resolution and graph management
- Must support state persistence (save/load project state)
- Must support agent lifecycle management (start, stop, pause, resume)
- Must support autonomous operation until all tasks completed

#### 2.1.2 Agent Base Class
**Location**: `src/ai_team/agents/agent.py`

**Requirements**:
- Must provide base class for all agents
- Must implement protocol communication with coordinator
- Must provide incremental work utilities
- Must support resource locking and conflict validation
- Must support checkpoint creation
- Must support task status reporting
- Must support dependency request handling
- Must support workspace isolation
- Must support agent state management (CREATED, STARTED, RUNNING, PAUSED, STOPPED, ERROR)
- Must support thread-based execution for concurrent agent operation
- Must integrate with logging system
- **REQ-2.1.2.1**: Acceptance-criteria command execution MUST only execute snippets that are explicitly described as runnable commands in the surrounding criteria text (e.g., lines containing “Command …”, “Run …”, “Execute …”) and MUST NOT execute inline code/config examples (to prevent false failures like running `hive: ^2.2.3` as a shell command)
- **REQ-2.1.2.2**: Artifact/path normalization MUST preserve leading dot paths (e.g., `.dart_tool/`) and must only remove a literal leading `./` when present (to prevent false “missing artifacts” blockers for hidden directories/files)
- **REQ-2.1.2.3**: When validating artifacts or running acceptance commands, agents MUST anchor paths and working directory to the configured project root (not a per-task workspace CWD) unless a task explicitly requires otherwise (to prevent writes/creates landing in the wrong directory)

#### 2.1.3 Task Queue
**Location**: `src/ai_team/utils/task_queue.py`

**Requirements**:
- Must support priority-based task scheduling
- Must handle dependency resolution
- Must support critical path analysis
- Must filter tasks by readiness (dependencies met)
- Must support task assignment to agents
- Must track task status transitions

#### 2.1.4 Conflict Prevention System
**Location**: `src/ai_team/utils/conflict_prevention.py`

**Requirements**:
- Must support resource locking (EXCLUSIVE, SHARED_READ, SHARED_WRITE)
- Must support workspace isolation bookkeeping per agent/task (e.g., isolated workspace paths and tracking); filesystem-level isolation is recommended but may be implemented incrementally
- Must detect conflicts before integration
- Must support atomic operations with rollback capability (at minimum: record reversible changes and return a rollback plan; applying the rollback to the filesystem may be best-effort depending on the executor)
- Must track file changes by agents
- Must validate changes before integration
- Must support lock timeout to prevent deadlocks
- Must automatically release locks on task completion
- **REQ-2.1.4.1**: When a task completes and its changes are already applied to the shared workspace, the system must mark those changes as integrated so downstream tasks are not blocked by false “pending task” conflicts

#### 2.1.5 Generic Project Runner
**Location**: `src/ai_team/generic_project_runner.py`

**Requirements**:
- Must read project configuration from `requirements.md` and `tasks.md`
- Must parse task definitions from markdown format
- Must support truly project-agnostic operation with zero project-specific assumptions
- Must rely primarily on `requirements.md` for project-specific decisions (secondary validation allowed; no project-specific hardcoding)
- Must support autonomous mode where supervisor analyzes `requirements.md` to determine team size
- Must auto-generate `run_team.py` template if missing (infrastructure file)
- Must validate infrastructure files (`run_team.py`) on initialization
- Must support generic agents that work with any project type
- Must support multiple agent types
- Must support configurable agent counts (optional - can be determined autonomously)
- Must support parallel execution optimization
- Must integrate with progress tracking and persistence
- Must support supervisor agent for issue detection and task generation
- Must NOT make assumptions about project type, framework, or file structure
- Must NOT hardcode paths, agent locations, or project-specific logic
- **REQ-2.1.5.1**: Runner initialization must comply with **REQ-10.1.4** (initialization log created immediately at initialization start)
- **REQ-2.1.5.2**: Runner initialization must comply with **REQ-10.1.5** (log initialization start timestamp immediately)
- **REQ-2.1.5.3**: Runner initialization must comply with **REQ-10.1.6** (log location/naming under `agent_logs/`)
- **REQ-2.1.5.4**: Runner initialization must comply with **REQ-10.1.7** (detect stuck initialization from log presence/content)
- **REQ-2.1.5.5**: Runner must generate and persist a unique team ID (see **REQ-1.2.1** and **REQ-1.2.2**)
- **REQ-2.1.5.6**: Runner must set team ID before any agent emits logs (see **REQ-1.2.3** and **REQ-10.1.8**)
- **REQ-2.1.5.7**: Runner must ensure team ID is present in all logs (see **REQ-1.2.3** and **REQ-10.1.8**)
- **REQ-2.1.5.8**: Runner must ensure team ID is present in progress reports (see **REQ-1.2.4** and **REQ-3.7.2.1**)
- **REQ-2.1.5.9**: Runner must expose team ID for validation/debugging workflows (see **REQ-1.2.5** and **REQ-11.3.\***)

### 2.2 Supporting Components

#### 2.2.1 Task Configuration Parser
**Location**: `src/ai_team/utils/task_config_parser.py`

**Requirements**:
- Must parse `requirements.md` file
- Must parse `tasks.md` file with task definitions
- Must extract task metadata (title, description, status, dependencies, etc.)
- Must support task status parsing (pending, ready, in_progress, blocked, completed, failed)
- Must support dependency parsing from task definitions
- **REQ-2.2.1.1**: Must correctly parse "Dependencies: none" as an empty list `[]`, not as `["none"]`
- **REQ-2.2.1.2**: Must handle variations of "no dependencies" (e.g., "none", "no dependencies", "no deps", "n/a", "na") as empty dependency lists
- **REQ-2.2.1.3**: Must filter out "none" keywords if they appear in dependency lists to prevent false dependency tracking
- **REQ-2.2.1.4**: Dependency parsing must not consume subsequent sections (e.g., "Acceptance Criteria", "Artifacts") and must only accept valid task IDs as dependencies (to prevent false missing-dependency deadlocks)
  - **Verification (Simulation/Execution)**:
    - Provide a minimal `tasks.md` fixture containing `Dependencies: none` and confirm the parsed task has `dependencies == []`.
    - Confirm a task with no dependencies can transition to `ready` (via coordinator status update) and be eligible for assignment.
    - Provide a fixture where `Acceptance Criteria:` appears after `Dependencies:` and confirm none of the acceptance bullets are parsed as dependencies.

#### 2.2.2 Progress Tracker
**Location**: `src/ai_team/utils/progress_tracker.py`

**Requirements**:
- Must track detailed progress for all tasks
- Must track agent status and workload
- Must track checkpoint history
- Must generate progress reports
- Must support progress visualization (at minimum: text-based/terminal visualization)

#### 2.2.3 Progress Persistence
**Location**: `src/ai_team/utils/progress_persistence.py`

**Requirements**:
- Must save progress to files
- Must load progress from files
- Must support incremental updates
- Must maintain task state across runs

#### 2.2.4 Agent Logger
**Location**: `src/ai_team/utils/agent_logger.py`

**Requirements**:
- Must support structured logging per agent
- Must log to separate files per agent
- Must support multiple log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- Must log task lifecycle events (start, complete, fail)
- Must log method entry/exit for execution flow tracing
- Must log execution flow steps
- Must support project directory configuration

#### 2.2.5 AI Client
**Location**: `src/ai_team/utils/ai_client.py`

**Requirements**:
- Must support OpenAI API integration
- Must support Anthropic API integration
- Must automatically detect and validate API keys
- **REQ-2.2.5.1**: System must detect Cursor-style keys (e.g., keys starting with `key_`) and treat them as **provider-specific** credentials:
  - If a Cursor-compatible endpoint is configured/available, the system MAY attempt to use the key.
  - If the key cannot be used successfully, the system MUST warn and fall back to non-LLM operation (or to other configured providers) rather than failing the run.
- Must support robust error handling and retry logic
- Must support comprehensive logging
- Must provide unified interface for multiple AI providers
  - **Verification (Execution)**:
    - Run with no valid provider keys and confirm the team still runs using non-LLM mechanisms (templates/heuristics/Cursor CLI where applicable).
    - Run with an invalid key and confirm the system logs a warning and continues (does not crash the runner loop).

#### 2.2.6 Cursor Integration
**Location**: `src/ai_team/utils/cursor_integration.py`

**Requirements**:
- Must support Cursor CLI client integration
- Must support file editing and creation
- Must support code generation
- Must support file reading and listing
- Must support command execution
- Must support workspace management
- Must provide Cursor task adapter for coding tasks

## 3. Functional Requirements

### 3.1 Task Management

#### 3.1.1 Task Definition
- **REQ-3.1.1.1**: System must support task definition with:
  - Unique task ID
  - Title and description
  - Estimated hours (1-4 hours per increment)
  - Dependencies (list of task IDs)
  - Acceptance criteria
  - Status tracking
  - Progress percentage (0-100)
  - Assigned agent
  - Timestamps (created, started, completed)
  - Artifacts (files created/modified)

#### 3.1.2 Task States
- **REQ-3.1.2.1**: System must support task states:
  - `pending`: Task defined but not started
  - `ready`: Dependencies met, ready to start
  - `assigned`: Assigned to an agent
  - `in_progress`: Agent actively working
  - `blocked`: Waiting on dependency or resource
  - `review`: Completed, awaiting review/integration
  - `completed`: Fully integrated and validated
  - `failed`: Task failed, needs attention

#### 3.1.3 Task Assignment
- **REQ-3.1.3.1**: System must assign tasks based on:
  - Agent specialization/capabilities
  - Current agent workload
  - Task dependencies (blocked tasks wait)
  - Agent availability

#### 3.1.4 Dependency Management
- **REQ-3.1.4.1**: System must:
  - Track task dependencies
  - Resolve dependency graph
  - Block tasks until dependencies complete
  - Unblock dependent tasks when prerequisites complete
  - Detect circular dependencies
  - Prioritize tasks based on dependencies

### 3.2 Agent Management

#### 3.2.1 Agent Creation
- **REQ-3.2.1.1**: System must support:
  - Creating agents with unique IDs
  - Agent specialization/capabilities
  - Multiple agent types (developer, tester, supervisor, etc.)
  - Configurable agent counts per type

#### 3.2.2 Agent Lifecycle
- **REQ-3.2.2.1**: System must support agent states:
  - `CREATED`: Agent created but not started
  - `STARTED`: Agent started and ready
  - `RUNNING`: Agent actively working
  - `PAUSED`: Agent paused
  - `STOPPED`: Agent stopped
  - `ERROR`: Agent in error state

#### 3.2.3 Agent Control
- **REQ-3.2.3.1**: System must support:
  - Starting agents
  - Stopping agents
  - Pausing agents
  - Resuming agents
  - Auto-restart on failure
  - State monitoring

#### 3.2.4 Agent Communication
- **REQ-3.2.4.1**: Agents must communicate through standardized messages:
  - Status updates (in_progress, blocked, completed)
  - Checkpoints (regular progress updates)
  - Dependency requests (report blockers)
  - Completion messages (task completion with results)

### 3.3 Incremental Work Protocol

#### 3.3.1 Increment Definition
- **REQ-3.3.1.1**: Each increment must be:
  - 1-4 hours of focused work
  - Independently testable/verifiable
  - Clearly defined with acceptance criteria
  - Small enough to complete in one session
  - Delivers tangible progress toward goal
  - Minimally coupled with in-progress work

#### 3.3.2 Checkpoint System
- **REQ-3.3.2.1**: System must support checkpoints:
  - Minimum: Every 30 minutes of active work
  - Required: Before switching tasks
  - Required: When reaching logical milestones
  - Required: When blocked or encountering issues
  - Must include progress percentage
  - Must include summary of changes
  - Must include next steps

#### 3.3.3 Work Session
- **REQ-3.3.3.1**: Each work session must:
  - Review task requirements
  - Check for dependencies (prerequisites complete)
  - Acquire locks on resources before modifying
  - Work in isolated workspace (if conflict prevention enabled)
  - Create checkpoints at logical points
  - Document decisions and approach
  - Release locks when done with resources

### 3.4 Conflict Prevention

#### 3.4.1 Resource Locking
- **REQ-3.4.1.1**: System must support:
  - Lock acquisition before resource modification
  - Lock types: EXCLUSIVE, SHARED_READ, SHARED_WRITE
  - Lock timeout to prevent deadlocks (default 60 minutes)
  - Automatic lock release on task completion
  - Manual lock release by agents

#### 3.4.2 Workspace Isolation
- **REQ-3.4.2.1**: System must support:
  - Isolated workspace per agent/task
  - Changes validated before integration
  - Conflict detection before integration
  - Atomic operations (all-or-nothing)
  - Workspace cleanup after task completion

#### 3.4.3 Conflict Detection
- **REQ-3.4.3.1**: System must:
  - Track all file changes by agents
  - Detect file conflicts before integration
  - Compare against integrated and pending changes
  - Block integration if conflicts detected
  - Support conflict resolution strategies

### 3.5 Configuration-Driven Operation

#### 3.5.1 Requirements File
- **REQ-3.5.1.1**: System must read `requirements.md` containing:
  - Project overview
  - Features to implement
  - Technical requirements
  - Technology stack
  - Framework preferences
- **REQ-3.5.1.2**: System must treat `requirements.md` as the **primary** source of truth:
  - Project-specific decisions must be derived from this file **first**
  - No hardcoded project type assumptions
  - File system signals (e.g., `pubspec.yaml`, `package.json`) may be used only as **secondary validation** or to confirm install/build/test commands, but must not introduce project-specific hardcoding
  - Supervisor analyzes this file to determine team size and generate tasks

#### 3.5.2 Tasks File
- **REQ-3.5.2.1**: System must read `tasks.md` containing:
  - Task definitions in markdown format
  - Task status and metadata
  - Dependencies
  - Acceptance criteria
  - Progress information
- **REQ-3.5.2.2**: System must auto-generate `tasks.md` if missing:
  - Supervisor uses Cursor CLI to analyze `requirements.md`
  - Tasks are generated based on requirements content
  - No template tasks - all tasks derived from requirements
  - **Verification (Execution/Inspection)**:
    - Delete/move `tasks.md`, start the team, and confirm a new `tasks.md` is created.
    - Confirm the generated tasks are project-appropriate (reflect the requirements) and contain explicit dependency relationships (not just a flat list).

#### 3.5.3 Project Type Detection
- **REQ-3.5.3.1**: System must:
  - Detect project type primarily from `requirements.md` content
  - May use file system checks (e.g., `pubspec.yaml`, `package.json`) as secondary confirmation to improve robustness
  - NOT hardcode project-specific paths or locations
  - NOT assume specific agent class locations or imports
  - Generate appropriate code structure based on requirements analysis
  - Work with any project type without project-specific assumptions
  - Use generic agents that adapt to project type through requirements analysis

#### 3.5.4 Autonomous Mode
- **REQ-3.5.4.1**: System must support autonomous operation:
  - Supervisor analyzes `requirements.md` to determine optimal team size
  - Team size based on project complexity, number of features, and technical requirements
  - Agent counts can be omitted - system determines automatically
  - Generic agents adapt their behavior based on requirements analysis
  - No manual configuration required for basic operation

### 3.6 AI-Powered Code Generation

#### 3.6.1 AI Integration
- **REQ-3.6.1.1**: System must support:
  - At least one code/task-generation backend (e.g., Cursor CLI and/or LLM API)
  - If LLM APIs are used: OpenAI API and/or Anthropic API
  - Automatic API key detection and validation (for the configured providers)
  - Automatic fallback to non-AI operation (templates or heuristics) when AI is unavailable

#### 3.6.2 Code Generation
- **REQ-3.6.2.1**: Agents must:
  - Generate code based on task descriptions and requirements
  - Generate complete, production-ready code
  - Generate test files for new code
  - Follow project-specific patterns and conventions

### 3.7 Progress Reporting

#### 3.7.1 Progress Report Creation
- **REQ-3.7.1.1**: System must create a progress report as one of the first actions when the team starts:
  - Progress report must be created before or immediately after task initialization
  - Progress report must be available from the earliest stages of team operation
  - Progress report must be stored in a standard location (e.g., `progress_reports/progress.md`)
  - **Verification (Execution)**:
    - Start the team with missing `tasks.md` and confirm the progress report exists and explicitly states tasks are not yet created (until they are generated).

#### 3.7.2 Progress Report Content
- **REQ-3.7.2.1**: Progress report must include:
  - Unique team ID (must be present in all progress reports, in header and throughout)
  - Current team status and state
  - Task status (if tasks exist)
  - Agent status and activity
  - Recent checkpoints and updates
  - Any blockers or issues
  - If tasks are not yet created, the report must explicitly state this condition

#### 3.7.3 Progress Report Updates
- **REQ-3.7.3.1**: System must continuously update the progress report:
  - Report must be updated when tasks are created or modified
  - Report must be updated when agents start, complete, or fail tasks
  - Report must be updated at each checkpoint
  - Report must reflect the actual current status of the team at all times
  - Report must be updated even when no tasks exist yet (showing initialization state)
  - **Verification (Execution/Inspection)**:
    - Observe at least one task state transition (e.g., `pending` → `ready` → `in_progress` → `completed`) and confirm the progress report reflects the change.
    - Confirm the report includes a clearly visible “Last Updated” indicator that changes over time while the team is running.

#### 3.7.4 Progress Report Availability
- **REQ-3.7.4.1**: Progress report must always be available:
  - Report must exist from team initialization
  - Report must be readable and accessible throughout team operation
  - Report must accurately reflect team status even when tasks are not yet defined
  - Report must indicate when the team is in initialization phase vs. active work phase

## 4. Non-Functional Requirements

### 4.1 Performance
- **REQ-4.1.1**: System must support parallel task execution
- **REQ-4.1.2**: System must minimize blocking between agents
- **REQ-4.1.3**: System must optimize task assignment for maximum parallelism
- **REQ-4.1.4**: System should support auto-scaling (spawn agents based on workload) (future)

### 4.2 Reliability
- **REQ-4.2.1**: System must handle agent failures gracefully
- **REQ-4.2.2**: System must support state persistence and recovery
- **REQ-4.2.3**: System must prevent deadlocks through lock timeouts
- **REQ-4.2.4**: System must support task retry on failure

### 4.3 Scalability
- **REQ-4.3.1**: System must support multiple agents (minimum 2, maximum configurable)
- **REQ-4.3.2**: System must support large numbers of tasks
- **REQ-4.3.3**: System must support complex dependency graphs

### 4.4 Maintainability
- **REQ-4.4.1**: System must be task-agnostic (works with any task type)
- **REQ-4.4.2**: System must be project-agnostic (works with any project)
  - Must NOT make assumptions about project type, framework, or structure
  - Must NOT hardcode project-specific paths, imports, or logic
  - Must rely primarily on `requirements.md` for project-specific decisions (secondary validation allowed; no project-specific hardcoding)
  - Must use generic agents that adapt to project type through requirements analysis
- **REQ-4.4.3**: System must support extensible tools/adapters (so new environments/editors/providers can be added without project-specific logic)
- **REQ-4.4.4**: System must follow clear architecture and design patterns

### 4.5 Observability
- **REQ-4.5.1**: System must provide comprehensive logging
- **REQ-4.5.2**: System must track progress and metrics
- **REQ-4.5.3**: System must support progress visualization
- **REQ-4.5.4**: System should provide status boards and dependency graphs (future)

## 5. Technical Requirements

### 5.1 Technology Stack
- **REQ-5.1.1**: System must be implemented in Python 3.x
- **REQ-5.1.2**: System must support threading for concurrent agent execution
- **REQ-5.1.3**: System must support file-based configuration (Markdown)
- **REQ-5.1.4**: System must support JSON for state persistence

### 5.2 Dependencies
- **REQ-5.2.1**: If OpenAI LLM integration is enabled, system must support the OpenAI Python library
- **REQ-5.2.2**: If Anthropic LLM integration is enabled, system must support the Anthropic Python library
- **REQ-5.2.3**: System must support optional python-dotenv for .env files

### 5.3 API Integration
- **REQ-5.3.1**: If OpenAI LLM integration is enabled, system must integrate with OpenAI API
- **REQ-5.3.2**: If Anthropic LLM integration is enabled, system must integrate with Anthropic API
- **REQ-5.3.3**: System must support Cursor CLI integration
- **REQ-5.3.4**: System must handle API errors gracefully with retry logic

### 5.4 File System
- **REQ-5.4.1**: System must read/write project files
- **REQ-5.4.2**: System must support workspace isolation
- **REQ-5.4.3**: System must track file changes
- **REQ-5.4.4**: System must support atomic file operations

## 6. Integration Requirements

### 6.1 Cursor Editor Integration
- **REQ-6.1.1**: System must support Cursor CLI client
- **REQ-6.1.2**: System must support Cursor task adapter
- **REQ-6.1.3**: System must support a tool registry for Cursor integration (e.g., `ToolRegistry`-style discovery of tools)
- **REQ-6.1.4**: System must enable Cursor agents to edit files and generate code

### 6.2 Version Control Integration
- **REQ-6.2.1**: System should support Git integration for artifact tracking (future)
- **REQ-6.2.2**: System should support commit management (future)

### 6.3 CI/CD Integration
- **REQ-6.3.1**: System should integrate with CI/CD for automated testing (future)
- **REQ-6.3.2**: System should support webhooks for notifications (future)

## 7. Configuration Requirements

### 7.1 Project Configuration
- **REQ-7.1.1**: Each project must have `requirements.md` file (mandatory)
  - This is the primary source of truth for project-specific information
  - System relies primarily on this file for project type, team sizing, and task generation
  - System must prefer `requirements.md` and may use file system checks only as secondary validation (no project-specific hardcoding)
  - System MUST analyze `requirements.md` content to determine project characteristics
- **REQ-7.1.2**: Each project must have `tasks.md` file (auto-generated if missing)
  - Supervisor generates tasks from `requirements.md` if file doesn't exist
  - Tasks are created based on requirements analysis
  - Task generation uses Cursor CLI to analyze requirements and create appropriate tasks
- **REQ-7.1.3**: Each project must have `run_team.py` runner script (auto-generated if missing)
  - System auto-generates a generic template if file is missing or corrupted
  - Template uses generic agents (`GenericDeveloperAgent`, `GenericTesterAgent`) that work with any project type
  - Template relies primarily on `requirements.md` and must not hardcode project-specific assumptions
  - Template is protected during cleanup operations (listed in `PROTECTED_FILE_PATTERNS`)
  - Template validation occurs during `GenericProjectRunner` initialization
  - Template generation makes zero assumptions about project type, framework, or structure

### 7.2 Agent Configuration
- **REQ-7.2.1**: System must support agent type registration
  - Default: Generic agents that work with any project type
  - Optional: Project-specific agent classes can be provided
- **REQ-7.2.2**: System must support configurable agent counts
  - Optional: Can be omitted for autonomous mode
  - Supervisor analyzes `requirements.md` to determine optimal team size
  - Autonomous sizing based on project complexity and requirements
- **REQ-7.2.3**: System must support agent specialization
  - Generic agents adapt specialization based on requirements analysis
  - No hardcoded specializations for specific project types

### 7.3 Environment Configuration
- **REQ-7.3.1**: System must support API keys via environment variables
- **REQ-7.3.2**: System must support `.env` file for API keys
- **REQ-7.3.3**: System must validate API keys on startup

## 8. Agent Requirements

### 8.1 Agent Base Class
- **REQ-8.1.1**: All agents must inherit from `Agent` base class
- **REQ-8.1.2**: All agents must implement `work(task: Task) -> bool` method
- **REQ-8.1.3**: All agents must register with coordinator
- **REQ-8.1.4**: All agents must support incremental work protocol

### 8.2 Agent Types
- **REQ-8.2.1**: System must support developer agents
  - Default: Generic developer agents that work with any project type
  - Agents analyze `requirements.md` to determine appropriate tools and workflows
- **REQ-8.2.2**: System must support tester agents
  - Default: Generic tester agents that work with any project type
  - Agents adapt testing approach based on requirements analysis
- **REQ-8.2.3**: System must support supervisor agents
  - Analyzes `requirements.md` to determine team size
  - Generates tasks from `requirements.md` if `tasks.md` is missing
  - Monitors team progress and detects issues
  - **REQ-8.2.3.1**: Supervisor must continuously monitor and check for all issues described in `supervisor_issues_checklist.md` (located in the parent directory) and all issues encountered during team operation
  - **REQ-8.2.3.2**: Supervisor must fix detected issues generically in the implementation when possible
  - **REQ-8.2.3.3**: Supervisor must add comprehensive logging when issues are detected to track root causes
  - **REQ-8.2.3.4**: Supervisor must persist fixes to tasks.md and other relevant files when correcting task states
  - **REQ-8.2.3.5**: Supervisor must log all found issues in `supervisor_issues_checklist.md` located in the parent directory of the project (one level up from the project directory)
  - **REQ-8.2.3.6**: The supervisor must only add issues to the file if they are not already present (check for duplicates before adding)
  - **REQ-8.2.3.7**: Each issue logged must be a high-level description only, without detailed IDs, timestamps, or fix information
  - **REQ-8.2.3.8**: The supervisor must continuously update the file as issues are detected
  - **REQ-8.2.3.9**: The supervisor must create the file during initialization if it doesn't exist
  - **REQ-8.2.3.10**: Supervisor must identify all tasks related to **project dependencies and their installation** and ensure they are present in `tasks.md`
    - Includes dependency/toolchain setup tasks (e.g., package manager install steps, dependency resolution, SDK/tooling verification, lockfile generation, and “install dependencies” steps required to build/run/test)
    - These tasks must be **prioritized early** (as prerequisites) and modeled explicitly as dependencies for tasks that require the environment to be set up
    - **Verification (Inspection)**:
      - In a newly generated `tasks.md`, confirm there are explicit tasks covering toolchain/dependency installation.
      - Confirm build/test/code tasks depend on these environment-setup tasks (dependency edges are present).
  - **REQ-8.2.3.11**: Supervisor must preserve **monotonic completion**:
    - The supervisor MUST NOT change a task from `COMPLETED` to any non-completed state (e.g., `READY`, `PENDING`, `BLOCKED`) during remediation.
    - If a “completed” task is later found to be missing artifacts/expected files, the supervisor MUST create follow-up **fix-up tasks** (or mark a separate verification task as failed/blocked) instead of resetting the original task.
    - **Verification (Execution/Inspection)**:
      - During a run, verify that completed task count in progress history never decreases.
      - If artifacts are detected missing for a completed task, verify a new fix-up task is created while the original remains `COMPLETED`.
- **REQ-8.2.4**: System must support generic agents (task-agnostic and project-agnostic)
  - Generic agents use task adapters to handle different project types
  - No project-specific logic in generic agents
  - Agents rely on `requirements.md` for project-specific decisions
- **REQ-8.2.5**: System must support coordinator agents (spawn/control other agents)

### 8.3 Agent Behavior
- **REQ-8.3.1**: Agents must request tasks from coordinator
- **REQ-8.3.2**: Agents must report status updates
- **REQ-8.3.3**: Agents must create checkpoints regularly
- **REQ-8.3.4**: Agents must report blockers immediately
- **REQ-8.3.5**: Agents must complete tasks with artifacts and results

## 9. Protocol Requirements

### 9.1 Communication Protocol
- **REQ-9.1.1**: System must support standardized message types:
  - Status Update
  - Dependency Request
  - Checkpoint
  - Completion
  - Agent Control

### 9.2 Task Protocol
- **REQ-9.2.1**: System must follow incremental work protocol:
  - Phase 0: Initialization (create progress report, initialize tracking)
  - Phase 1: Task Planning & Decomposition
  - Phase 2: Incremental Execution
  - Phase 3: Integration & Validation

#### 9.2.1 Initialization Phase
- **REQ-9.2.1.1**: During initialization, system must:
  - Generate unique team ID as first action
  - Create progress report as first priority action (including team ID)
  - Initialize progress tracking system (with team ID)
  - Set up monitoring and logging infrastructure (with team ID)
  - If tasks do not exist yet, progress report must clearly state this
  - Progress report must be available before any other work begins
  - All initialization logs must include team ID from the start

### 9.3 Checkpoint Protocol
- **REQ-9.3.1**: System must enforce checkpoint requirements:
  - Minimum every 30 minutes
  - Before task switching
  - At logical milestones
  - When blocked

## 10. Logging and Monitoring Requirements

### 10.1 Logging
- **REQ-10.1.1**: System must log to `agent_logs/` directory
- **REQ-10.1.2**: System must create separate log files per agent
- **REQ-10.1.3**: System must support multiple log levels
- **REQ-10.1.4**: System must immediately create an initialization log file when team initialization begins (before any other initialization steps)
- **REQ-10.1.5**: System must log the initialization start timestamp immediately upon creating the log file
- **REQ-10.1.6**: This initialization log must be created in `agent_logs/` directory with a clear name (e.g., `initialization.log` or `team_initialization.log`)
- **REQ-10.1.7**: This allows detection of cases where the team never finishes initializing by checking if the log file exists and contains only initialization start timestamp without completion
- **REQ-10.1.8**: System must include unique team ID in all log entries
- **REQ-10.1.9**: Team ID must be present in every log message across all agents and components
- **REQ-10.1.10**: Team ID must be included in log file headers/metadata for easy identification
- **REQ-10.1.11**: System must log task lifecycle events
- **REQ-10.1.12**: System must log method entry/exit for execution flow

### 10.2 Monitoring
- **REQ-10.2.1**: System must track task progress
- **REQ-10.2.2**: System must track agent status
- **REQ-10.2.3**: System must track checkpoint history
- **REQ-10.2.4**: System must generate and maintain progress reports

#### 10.2.1 Progress Report Requirements
- **REQ-10.2.1.1**: System must create progress report as first action:
  - See **REQ-3.7.\*** (progress reporting requirements) and **REQ-1.2.4** (team ID in progress reports)

## 11. Testing Requirements

### 11.1 Unit Testing
- **REQ-11.1.1**: System should have unit tests for core components
- **REQ-11.1.2**: System should test task management
- **REQ-11.1.3**: System should test conflict prevention
- **REQ-11.1.4**: System should test dependency resolution

### 11.2 Integration Testing
- **REQ-11.2.1**: System should test agent coordination
- **REQ-11.2.2**: System should test end-to-end workflows
- **REQ-11.2.3**: System should test state persistence
- **REQ-11.2.4**: System should test team ID propagation across all components

### 11.3 Validation and Debugging
- **REQ-11.3.1**: System must support team implementation validation using team ID
- **REQ-11.3.2**: Team ID must enable filtering and searching logs for specific team instances
- **REQ-11.3.3**: Team ID must enable correlation of progress reports with log entries
- **REQ-11.3.4**: Team ID must be traceable across all system components for debugging purposes

## 12. Documentation Requirements

### 12.1 User Documentation
- **REQ-12.1.1**: System must provide README with overview
- **REQ-12.1.2**: System must provide quick start guide
- **REQ-12.1.3**: System must provide configuration guide
- **REQ-12.1.4**: System must provide protocol documentation

### 12.2 Developer Documentation
- **REQ-12.2.1**: System must document architecture
- **REQ-12.2.2**: System must document API reference
- **REQ-12.2.3**: System must provide examples
- **REQ-12.2.4**: System must document extension points

### 12.3 Operational Documentation
- **REQ-12.3.1**: System must document logging guide
- **REQ-12.3.2**: System must document conflict prevention guide
- **REQ-12.3.3**: System must document troubleshooting guide

## 13. Constraints and Assumptions

### 13.1 Constraints
- **CON-13.1.1**: System requires Python 3.x
- **CON-13.1.2**: If LLM API-backed features are enabled, system requires valid provider API keys and network access; otherwise system must remain operable using non-LLM mechanisms (e.g., Cursor CLI or templates)
- **CON-13.1.3**: System requires file system access for project files
- **CON-13.1.4**: System requires network access for API calls

### 13.2 Assumptions
- **ASM-13.2.1**: Projects use Markdown for configuration files
- **ASM-13.2.2**: Tasks can be broken into 1-4 hour increments
- **ASM-13.2.3**: Agents can work independently on isolated tasks
- **ASM-13.2.4**: File-based coordination is acceptable (no distributed system required)

## 14. Success Criteria

### 14.1 Functional Success
- ✅ System can coordinate multiple agents on a project
- ✅ System can manage task dependencies correctly
- ✅ System can prevent conflicts between agents
- ✅ System can track progress and checkpoints
- ✅ System can work with any project type through configuration
- ✅ System relies primarily on `requirements.md` with zero project-specific assumptions (secondary validation allowed; no project-specific hardcoding)
- ✅ System auto-generates infrastructure files (`run_team.py`) when missing
- ✅ System uses generic agents that adapt to any project type
- ✅ Supervisor analyzes `requirements.md` to determine team size and generate tasks

### 14.2 Quality Success
- ✅ System is reliable (handles failures gracefully)
- ✅ System is maintainable (clear architecture)
- ✅ System is observable (comprehensive logging)
- ✅ System is extensible (new tools/adapters/providers can be added without project-specific logic)

## 15. Future Enhancements

### 15.1 Planned Features
- Git integration for artifact tracking
- CI/CD integration for automated testing
- Webhook support for notifications
- Project management tool integration (Jira, Trello)
- Enhanced visualization and dashboards
- Multi-framework template system
- Custom code generators per project type

### 15.2 Research Areas
- Advanced conflict resolution strategies
- Machine learning for task assignment optimization
- Predictive dependency analysis
- Automated test generation

## 16. Compliance and Standards

### 16.1 Code Quality
- **REQ-16.1.1**: Code must follow Python best practices (PEP 8)
- **REQ-16.1.2**: Code must include error handling
- **REQ-16.1.3**: Code must include helpful comments
- **REQ-16.1.4**: Code must be production-ready

### 16.2 Security
- **REQ-16.2.1**: System must not expose API keys in logs
- **REQ-16.2.2**: System must validate API keys securely
- **REQ-16.2.3**: System must handle sensitive data appropriately

## Document Version

- **Version**: 1.2
- **Date**: 2025-12-28
- **Status**: Current

---

*This document defines the comprehensive requirements for the AI Agent Team implementation. All requirements should be considered when implementing, extending, or maintaining the system.*

