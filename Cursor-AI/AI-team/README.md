# AI Agent Team Protocol

A protocol and implementation system for coordinating multiple AI agents to work together incrementally on projects.

## Overview

This system enables multiple AI agents to collaborate on projects by:
- Breaking work into small, manageable increments
- Managing task dependencies and coordination
- Tracking progress with checkpoints
- Enabling parallel work where possible
- Ensuring incremental integration

## Key Features

✅ **Incremental Work**: Tasks broken into 1-4 hour increments  
✅ **Dependency Management**: Automatic dependency resolution  
✅ **Progress Tracking**: Checkpoint system for monitoring progress  
✅ **Agent Coordination**: Centralized coordinator manages all agents  
✅ **Communication Protocol**: Standardized messaging between agents  
✅ **Conflict Prevention**: Resource locking, workspace isolation, conflict detection  
✅ **Autonomous Operation**: Runs independently until all tasks completed  
✅ **Auto-Scaling**: Automatically spawns agents based on workload  
✅ **Parallel Execution**: Maximizes parallel task execution  
✅ **Task-Agnostic**: Works with any task type through adapters  
✅ **Extensible Tooling**: Plugin system for adding capabilities  
✅ **Cursor Integration**: Built-in support for Cursor editor agents  
✅ **State Persistence**: Save/load project state  

## Architecture

### Core Components

1. **AgentCoordinator** (`agent_coordinator.py`)
   - Manages all agents and tasks
   - Handles task assignment and dependencies
   - Processes agent messages
   - Tracks progress and checkpoints
   - Integrates conflict prevention system

2. **Agent Base Class** (`agent.py`)
   - Base class for all agents
   - Implements protocol communication
   - Provides incremental work utilities
   - Resource locking and conflict validation

3. **Task Queue** (`task_queue.py`)
   - Priority-based task scheduling
   - Dependency resolution
   - Critical path analysis

4. **Conflict Prevention** (`conflict_prevention.py`)
   - Resource locking system
   - Workspace isolation
   - Conflict detection and validation
   - Atomic operations with rollback

## Task-Agnostic Design

The protocol is **task-agnostic** and works with any task type:

- **Adapters**: Different task types use adapters (coding, writing, analysis, etc.)
- **Tools**: Extensible tool system for adding capabilities
- **Configuration**: Domain-specific configurations
- **Generic Agents**: Agents that work with any task type
- **Cursor Integration**: Built-in support for Cursor editor agents

See `example_task_agnostic.py` for a complete example.

## Cursor Agent Integration

The protocol includes built-in support for Cursor agents:

```python
from cursor_integration import CursorTool, CursorTaskAdapter, create_cursor_tool_registry
from generic_agent import GenericAgent

# Create Cursor tool and registry
cursor_tool, tool_registry = create_cursor_tool_registry()

# Create Cursor adapter
cursor_adapter = CursorTaskAdapter()
cursor_adapter.set_cursor_tool(cursor_tool)

# Register adapter
adapter_registry = TaskAdapterRegistry()
adapter_registry.register(cursor_adapter)

# Create Cursor-enabled agent
agent = GenericAgent(
    "cursor-agent-1",
    coordinator,
    adapter_registry=adapter_registry,
    tool_registry=tool_registry
)
```

**Cursor Tool Features**:
- File editing and creation
- Code generation
- File reading and listing
- Command execution
- Workspace management

**Cursor Task Adapter**:
- Automatically detects coding tasks
- Generates code files based on task descriptions
- Creates test files
- Manages workspace structure

See `example_cursor_agent.py` for a complete example.

## Configuration: Single Source of Truth

**Use `ai_team_settings.local.json` as your single source of truth for API keys.**

1. Copy the example: `cp SETTINGS.example.json ai_team_settings.local.json`
2. Edit `ai_team_settings.local.json` with your real API keys
3. The file is gitignored (never committed)

**Precedence** (highest → lowest):
- Environment variables (optional override)
- `ai_team_settings.local.json` (recommended; single source of truth)

See `SETTINGS.example.json` for the template format.

## Run automation tests

```bash
python run_tests.py
```

## Quick Start

### 1. Create a Coordinator

```python
from agent_coordinator import AgentCoordinator, Task

coordinator = AgentCoordinator(project_name="My Project")
```

### 2. Define Tasks

```python
tasks = [
    Task(
        id="task-1",
        title="Setup database",
        description="Create database schema",
        estimated_hours=2.0,
        dependencies=[],
        acceptance_criteria=["Schema created", "Migrations tested"]
    ),
    Task(
        id="task-2",
        title="Create API",
        description="Build REST API endpoints",
        estimated_hours=3.0,
        dependencies=["task-1"],  # Depends on task-1
        acceptance_criteria=["Endpoints working", "Tests passing"]
    )
]

coordinator.add_tasks(tasks)
```

### 3. Create Agents

```python
from agent import Agent, IncrementalWorkMixin

class MyAgent(Agent, IncrementalWorkMixin):
    def __init__(self, agent_id: str, coordinator: AgentCoordinator):
        super().__init__(agent_id, coordinator, specialization="backend")
    
    def work(self, task: Task) -> bool:
        # Break work into increments
        increments = self.create_increments(task, [
            "Design solution",
            "Implement core logic",
            "Add error handling",
            "Write tests"
        ])
        
        for increment in increments:
            # Work on increment
            success = self.work_increment(
                task,
                increment,
                lambda: do_actual_work()  # Your work function
            )
            if not success:
                return False
        
        # Complete task
        self.complete_task(
            task.id,
            result="Task completed successfully",
            artifacts=["file1.py", "file2.py"],
            tests="All tests passing"
        )
        return True
```

### 4. Create and Control Agents

```python
# Option 1: Create agents and let coordinator start them
from agent_manager import AgentManager

agent_manager = AgentManager(coordinator)
agent_manager.register_agent_type("worker", MyAgent)

# Coordinator creates and starts agents
agent1 = agent_manager.create_agent("agent-1", "worker", auto_start=True)
agent2 = agent_manager.create_agent("agent-2", "worker", auto_start=True)

# Option 2: Manual control
agent1 = MyAgent("agent-1", coordinator)
agent2 = MyAgent("agent-2", coordinator)

# Coordinator starts agents
coordinator.start_agent("agent-1")
coordinator.start_agent("agent-2")

# Coordinator can control agents
coordinator.pause_agent("agent-1")
coordinator.resume_agent("agent-1")
coordinator.stop_agent("agent-1")

# Option 3: Coordinator agent spawns other agents
from agent_manager import CoordinatorAgent

coord_agent = CoordinatorAgent("coord-1", coordinator)
coord_agent.spawn_agent("worker-1", "worker", auto_start=True)
coord_agent.control_agent("worker-1", "pause")
```

## Protocol Details

### Task States

- `pending`: Task defined but not started
- `ready`: Dependencies met, ready to start
- `assigned`: Assigned to an agent
- `in_progress`: Agent actively working
- `blocked`: Waiting on dependency
- `review`: Completed, awaiting review
- `completed`: Fully integrated
- `failed`: Task failed

### Communication Messages

Agents communicate through standardized messages:

1. **Status Update**: Report current status and progress
2. **Checkpoint**: Regular progress checkpoints (every 15-30 min)
3. **Dependency Request**: Report blockers
4. **Completion**: Task completion with results

### Incremental Work Guidelines

- **Size**: 1-4 hours per increment
- **Value**: Delivers tangible progress
- **Testability**: Can be verified independently
- **Isolation**: Minimal coupling with in-progress work
- **Checkpoints**: Create checkpoints every 30 minutes minimum

## Example Usage

### Autonomous Team (Recommended)

Run a team that works independently until all tasks are completed:

```python
from autonomous_coordinator import run_autonomous_team
from agent_coordinator import AgentCoordinator, Task
from agent import Agent, IncrementalWorkMixin

# Define your agent class
class MyAgent(Agent, IncrementalWorkMixin):
    def work(self, task: Task) -> bool:
        # Your work implementation
        pass

# Define tasks
tasks = [Task(...), Task(...)]

# Run autonomously - no human intervention needed!
run_autonomous_team(
    coordinator=AgentCoordinator("My Project"),
    tasks=tasks,
    agent_class=MyAgent,
    min_agents=2,
    max_agents=5
)
```

See `example_autonomous.py` for a complete example.

### Manual Control

See `example_usage.py` for manual agent control:
- Multiple specialized agents (backend, frontend, database)
- Task dependencies
- Incremental work execution
- Progress tracking

Run examples:

```bash
# Autonomous team (runs until completion)
python example_autonomous.py

# Manual control example
python example_usage.py

# Coordinator control example
python example_coordinator_control.py
```

## API Reference

### AgentCoordinator

```python
coordinator = AgentCoordinator(project_name="My Project")

# Register agents
coordinator.register_agent("agent-1")

# Add tasks
coordinator.add_task(task)
coordinator.add_tasks([task1, task2])

# Assign tasks
coordinator.assign_task("task-1", "agent-1")

# Get status
status = coordinator.get_status_board()
graph = coordinator.get_dependency_graph()

# Save/load state
coordinator.save_state("state.json")
coordinator.load_state("state.json")
```

### Agent

```python
class MyAgent(Agent):
    def work(self, task: Task) -> bool:
        # Implement your work logic
        # Use helper methods:
        self.send_status_update(task.id, TaskStatus.IN_PROGRESS, progress=50)
        self.send_checkpoint(task.id, 50, "Half done", "Continue work")
        self.complete_task(task.id, "Done!", artifacts=["file.py"])
        return True
```

## Best Practices

1. **Break tasks into increments**: Use `create_increments()` to structure work
2. **Lock resources before modifying**: Use `request_resource_lock()` before file changes
3. **Work in isolation**: Use isolated workspaces when possible
4. **Validate changes**: Check for conflicts before completing tasks
5. **Checkpoint regularly**: At least every 30 minutes
6. **Report blockers early**: Use `report_blocked()` immediately
7. **Document decisions**: Include reasoning in checkpoint messages
8. **Test incrementally**: Verify each increment works
9. **Release locks promptly**: Always release locks when done
10. **Save state**: Use `save_state()` for persistence

## Conflict Prevention

The system includes comprehensive conflict prevention to ensure agents don't interfere with each other:

- **Resource Locking**: Acquire locks before modifying files
- **Workspace Isolation**: Each agent works in isolated workspace
- **Conflict Detection**: Validates changes before integration
- **Atomic Operations**: All-or-nothing change application

See `CONFLICT_PREVENTION_GUIDE.md` for detailed usage examples.

## Project Structure

```
.
├── PROTOCOL.md                    # Detailed protocol specification
├── CONFLICT_PREVENTION_GUIDE.md   # Conflict prevention guide
├── TASK_AGNOSTIC_DESIGN.md        # Task-agnostic design documentation
├── CURSOR_INTEGRATION.md          # Cursor integration guide
├── agent_coordinator.py           # Core coordination system
├── agent.py                       # Agent base class and utilities
├── agent_manager.py               # Agent lifecycle management
├── autonomous_coordinator.py      # Autonomous team runner
├── parallel_execution.py          # Parallel execution optimizer
├── conflict_prevention.py         # Conflict prevention system
├── task_adapter.py               # Task-agnostic adapter system
├── tool_system.py                # Extensible tool/plugin system
├── generic_agent.py              # Generic task-agnostic agent
├── task_config.py                # Domain configuration system
├── cursor_integration.py         # Cursor editor integration
├── task_queue.py                  # Task queue and scheduling
├── visualizer.py                  # Visualization utilities
├── example_autonomous.py          # Autonomous team example
├── example_usage.py               # Manual control example
├── example_coordinator_control.py # Coordinator control example
├── example_task_agnostic.py       # Task-agnostic usage example
├── example_cursor_agent.py        # Cursor agent example
├── example_adapters.py            # Example task adapters
├── example_conflict_prevention.py # Conflict prevention example
├── requirements.txt               # Dependencies
└── README.md                      # This file
```

## Agent Lifecycle Management

Agents can be controlled by the coordinator or coordinator agents:

```python
# Start/stop agents
coordinator.start_agent("agent-1")
coordinator.stop_agent("agent-1")

# Pause/resume agents
coordinator.pause_agent("agent-1")
coordinator.resume_agent("agent-1")

# Get agent state
state = coordinator.get_agent_state("agent-1")  # CREATED, STARTED, RUNNING, PAUSED, STOPPED, ERROR

# Control all agents
coordinator.start_all_agents()
coordinator.stop_all_agents()
```

### Coordinator Agents

Special agents that can spawn and control other agents:

```python
from agent_manager import CoordinatorAgent

coord_agent = CoordinatorAgent("coord-1", coordinator)
coord_agent.start()

# Spawn other agents
worker = coord_agent.spawn_agent("worker-1", "worker", auto_start=True)

# Control agents
coord_agent.control_agent("worker-1", "pause")
coord_agent.control_agent("worker-1", "resume")
coord_agent.control_agent("worker-1", "stop")
```

## Extending the System

### Custom Agent Types

Create specialized agents by inheriting from `Agent`:

```python
class DatabaseAgent(Agent, IncrementalWorkMixin):
    def __init__(self, agent_id: str, coordinator: AgentCoordinator):
        super().__init__(agent_id, coordinator, specialization="database")
    
    def work(self, task: Task) -> bool:
        # Database-specific work logic
        pass
```

Register agent types for spawning:

```python
agent_manager = AgentManager(coordinator)
agent_manager.register_agent_type("database", DatabaseAgent, "database")

# Spawn agents on demand
agent = agent_manager.create_agent("db-1", "database", auto_start=True)
```

### Custom Prioritization

Override task selection in `Agent.request_task()` or use `TaskQueue.get_next_task()` with custom logic.

### Integration with External Systems

- Connect to version control (Git) for artifact tracking
- Integrate with CI/CD for automated testing
- Add webhooks for real-time notifications
- Connect to project management tools (Jira, Trello, etc.)

## License

This project is provided as-is for coordinating AI agent teams.

## Contributing

When extending this system:
1. Follow the protocol in `PROTOCOL.md`
2. Maintain incremental work principles
3. Add checkpoints to long-running operations
4. Update documentation for new features

