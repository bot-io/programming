# Configuration-Driven Protocol Implementation

## Overview

The AI Agent Team system is now **fully project-agnostic and configuration-driven**. Agents read from `requirements.md` and `tasks.md` to determine what to build, without hardcoded project-specific logic.

## Key Changes

### 1. Requirements-Driven Code Generation

**Before**: Agents had hardcoded logic for specific project types (e.g., React Native)

**After**: Agents read `requirements.md` to detect:
- Project type (React Native, Flutter, etc.)
- Technology stack
- Features to implement
- Framework preferences

### 2. Dynamic Project Type Detection

```python
def _detect_project_type(self) -> str:
    """Detect project type from requirements"""
    req_content = self.requirements.get('raw_content', '').lower()
    
    if 'react native' in req_content:
        return 'react_native'
    elif 'flutter' in req_content:
        return 'flutter'
    # ... detects from requirements
```

### 3. Configuration-Based File Creation

Agents create files based on:
- **Task description** (from `tasks.md`)
- **Requirements** (from `requirements.md`)
- **Project type** (detected from requirements)

Not hardcoded project-specific logic.

## Implementation Details

### Agent Initialization

```python
class MobileDeveloperAgent(Agent, IncrementalWorkMixin):
    def __init__(self, agent_id: str, coordinator, specialization: str = "developer"):
        super().__init__(agent_id, coordinator, specialization)
        self.requirements = None  # Loaded from requirements.md
        self.project_dir = None    # Set from GenericProjectRunner
```

### Requirements Loading

```python
def _load_requirements(self):
    """Load requirements from configuration file"""
    from task_config_parser import TaskConfigParser
    parser = TaskConfigParser(self.project_dir)
    self.requirements = parser.parse_requirements()
```

### Code Generation Flow

1. **Load Requirements**: Read `requirements.md` to understand project
2. **Detect Project Type**: Determine framework/technology from requirements
3. **Read Task**: Get task details from `tasks.md`
4. **Generate Code**: Create files based on requirements + task, not hardcoded logic

## Benefits

1. **Project Agnostic**: Same agents work for any project type
2. **Configuration Driven**: All project details come from text files
3. **No Hardcoding**: No project-specific logic in agent code
4. **Easy Extension**: Add new project types by updating requirements

## Usage

### For Any Project

1. Create `requirements.md` describing:
   - Project type (React Native, Flutter, Python, etc.)
   - Features needed
   - Technology stack

2. Create `tasks.md` with tasks

3. Create `run_team.py`:
```python
from generic_project_runner import GenericProjectRunner
from my_agents import DeveloperAgent, TesterAgent

runner = GenericProjectRunner(
    project_dir='.',
    agent_classes={
        'developer': DeveloperAgent,
        'tester': TesterAgent
    }
)
runner.run()
```

4. Run: `python run_team.py`

The agents will automatically:
- Read requirements to understand project type
- Generate appropriate code structure
- Work on tasks based on configuration

## Example: Switching Project Types

**React Native Project** (`requirements.md`):
```markdown
## Technical Requirements
- React Native framework
- Cross-platform mobile app
```

**Flutter Project** (`requirements.md`):
```markdown
## Technical Requirements
- Flutter framework
- Cross-platform mobile app
```

Same agents, different output based on requirements!

## Future Enhancements

1. **Multi-Framework Support**: Add Flutter, Python web, etc.
2. **Template System**: Use templates based on project type
3. **Smart Detection**: Better project type detection from requirements
4. **Custom Generators**: Allow custom code generators per project type

