# Configuration-Driven AI Agent Team System

## Overview

The AI Agent Team system is now fully configuration-driven. Instead of creating Python scripts for each project, you simply create text files that describe requirements and tasks. The system automatically reads these files and manages the agent team.

## File Structure

Each project should have:

1. **`requirements.md`** - Project requirements and specifications
2. **`tasks.md`** - List of tasks with their status and details
3. **`run_team.py`** - Simple runner script (one-time setup per project)

## File Formats

### requirements.md

A Markdown file describing the project:

```markdown
# Project Requirements

## Overview
Describe your project here.

## Features
- Feature 1
- Feature 2

## Technical Requirements
- Requirement 1
- Requirement 2
```

### tasks.md

A Markdown file listing all tasks:

```markdown
# Tasks

## Pending Tasks

### task-id-1
- Title: Task Title
- Description: Task description here.
- Status: pending|ready|in_progress|blocked|completed|failed
- Progress: 0-100
- Estimated Hours: 2.0
- Dependencies: task-id-2, task-id-3
- Assigned Agent: agent-id
- Created: 2024-01-01 10:00:00
- Started: 2024-01-01 11:00:00
- Completed: 2024-01-01 13:00:00
- Artifacts: file1.py, file2.py
- Acceptance Criteria:
  - Criterion 1
  - Criterion 2
```

**Status Values:**
- `pending` - Task not yet started
- `ready` - Task ready to be assigned
- `in_progress` - Task currently being worked on
- `blocked` - Task blocked by dependencies
- `completed` - Task completed
- `failed` - Task failed

### run_team.py

A simple Python script that sets up the runner:

```python
from generic_project_runner import GenericProjectRunner
from my_agents import DeveloperAgent, TesterAgent, PMAgent

def main():
    runner = GenericProjectRunner(
        project_dir='.',
        agent_classes={
            'developer': DeveloperAgent,
            'tester': TesterAgent,
            'pm': PMAgent
        }
    )
    runner.run()

if __name__ == '__main__':
    main()
```

## Usage

### 1. Create Project Structure

```bash
mkdir my_project
cd my_project
```

### 2. Create requirements.md

Write your project requirements in Markdown format.

### 3. Create tasks.md

List all tasks in the format shown above. You can add tasks manually or let the system create a template.

### 4. Create run_team.py

Create a simple runner script that imports your agent classes.

### 5. Run the Team

```bash
python run_team.py
```

## Automatic Updates

The system automatically:

- **Reads** tasks from `tasks.md` on startup
- **Updates** `tasks.md` with current status, progress, and assignments
- **Saves** detailed progress to `progress_reports/progress.md`
- **Tracks** all changes and checkpoints

## Adding New Tasks

Simply edit `tasks.md` and add a new task block:

```markdown
### new-task-id
- Title: New Task
- Description: Task description
- Status: pending
- Progress: 0
- Estimated Hours: 1.0
- Dependencies: 
- ...
```

Then restart the team or the system will pick it up on the next run.

## Updating Requirements

Edit `requirements.md` directly. The system reads it on startup but doesn't modify it automatically.

## Progress Tracking

Progress is automatically saved to:
- `tasks.md` - Updated with current task statuses
- `progress_reports/progress.md` - Detailed progress report
- `progress_reports/progress.json` - Machine-readable snapshot

## Benefits

1. **No Python Scripts Needed** - Just edit text files
2. **Version Control Friendly** - All config in Markdown
3. **Human Readable** - Easy to understand and modify
4. **Automatic Updates** - System keeps files in sync
5. **Project Agnostic** - Works for any project

## Example: DualBookReader

See `test_demo_dualbook/` for a complete example:
- `requirements.md` - Project requirements
- `tasks.md` - Current tasks
- `run_team.py` - Runner script

Run it with:
```bash
cd test_demo_dualbook
python run_team.py
```

## Migration from Old System

To migrate an existing project:

1. Extract tasks from your Python task file
2. Convert to `tasks.md` format
3. Create `requirements.md` from project docs
4. Create `run_team.py` with your agent classes
5. Run the new system!

The old Python task files can be kept for reference but are no longer needed.

