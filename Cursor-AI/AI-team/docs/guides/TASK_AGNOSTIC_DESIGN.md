# Task-Agnostic Protocol Design

## Overview

The protocol is designed to be **task-agnostic**, meaning it can work with any type of task through a flexible adapter and tool system. This allows the same protocol to be used for:

- Software development (coding, testing, debugging)
- Content creation (writing, editing, documentation)
- Data analysis (analysis, visualization, reporting)
- Research tasks
- Administrative tasks
- Any other task type

## Architecture

### 1. Task Adapter System

**Purpose**: Allows different task types to be handled through specialized adapters.

**Components**:
- `TaskAdapter`: Base interface for task type adapters
- `TaskAdapterRegistry`: Registry for managing adapters
- `GenericTaskAdapter`: Fallback adapter for any task type
- `TaskContext`: Execution context passed to adapters

**How it works**:
1. Each task type has an adapter (e.g., `CodingTaskAdapter`, `WritingTaskAdapter`)
2. Adapters implement:
   - `can_handle()`: Check if adapter can handle a task
   - `validate_task()`: Validate task configuration
   - `prepare_context()`: Prepare execution context
   - `execute()`: Execute the task
   - `get_artifacts()`: Get created artifacts

3. The system automatically selects the appropriate adapter for each task

**Example**:
```python
# Register adapters
registry = TaskAdapterRegistry()
registry.register(CodingTaskAdapter())
registry.register(WritingTaskAdapter())

# System automatically uses correct adapter for each task
```

### 2. Tool System

**Purpose**: Provides extensible capabilities that agents can use.

**Components**:
- `Tool`: Base interface for tools
- `ToolRegistry`: Registry for managing tools
- `ToolExecutor`: Executes tools with context

**Built-in Tools**:
- `FileSystemTool`: File operations
- `APITool`: API calls
- `CodeExecutionTool`: Code execution

**Custom Tools**:
You can create custom tools for any capability:
```python
class CustomTool(Tool):
    def execute(self, *args, **kwargs) -> ToolResult:
        # Your tool logic
        return ToolResult(success=True, output=result)
```

### 3. Generic Agent

**Purpose**: Agent that works with any task type using adapters.

**Features**:
- Automatically selects appropriate adapter for each task
- Uses tools from tool registry
- Works with any task type without modification

**Usage**:
```python
agent = GenericAgent(
    "agent-1",
    coordinator,
    adapter_registry=registry,
    tool_registry=tool_registry
)
```

### 4. Domain Configuration

**Purpose**: Customize protocol behavior for different domains.

**Components**:
- `DomainConfig`: Configuration for a domain
- `DomainConfigManager`: Manages domain configurations

**Predefined Domains**:
- Software Development
- Content Creation
- Data Analysis

**Custom Domains**:
```python
config = DomainConfig(
    domain_name="my_domain",
    task_types=["custom_type1", "custom_type2"],
    agent_specializations=["specialist1", "specialist2"],
    config_overrides={"checkpoint_interval": 15}
)
```

## Creating Custom Adapters

### Step 1: Create Adapter Class

```python
from task_adapter import TaskAdapter, TaskContext

class MyTaskAdapter(TaskAdapter):
    def __init__(self, config=None):
        super().__init__("my_task_type", config)
    
    def can_handle(self, task: Task) -> bool:
        # Check if this adapter can handle the task
        return "my_keyword" in task.description.lower()
    
    def validate_task(self, task: Task) -> tuple[bool, List[str]]:
        # Validate task configuration
        issues = []
        # Add validation logic
        return len(issues) == 0, issues
    
    def prepare_context(self, task: Task, agent_id: str) -> TaskContext:
        # Prepare execution context
        return TaskContext(task=task, agent_id=agent_id)
    
    def execute(self, context: TaskContext) -> bool:
        # Execute the task
        # Your task execution logic here
        return True
    
    def get_artifacts(self, context: TaskContext) -> List[str]:
        # Return list of created artifacts
        return context.metadata.get('artifacts', [])
```

### Step 2: Register Adapter

```python
registry = TaskAdapterRegistry()
registry.register(MyTaskAdapter())
```

### Step 3: Use with Generic Agent

```python
agent = GenericAgent(
    "agent-1",
    coordinator,
    adapter_registry=registry
)
```

## Creating Custom Tools

### Step 1: Create Tool Class

```python
from tool_system import Tool, ToolResult

class MyTool(Tool):
    def __init__(self, config=None):
        super().__init__("my_tool", config)
    
    def validate(self, *args, **kwargs) -> tuple[bool, Optional[str]]:
        # Validate inputs
        return True, None
    
    def execute(self, *args, **kwargs) -> ToolResult:
        # Execute tool
        result = do_something()
        return ToolResult(success=True, output=result)
```

### Step 2: Register Tool

```python
registry = ToolRegistry()
registry.register(MyTool(), category="my_category")
```

### Step 3: Use in Agent

```python
# In agent's work method
result = self.use_tool("my_tool", param1=value1)
if result.success:
    # Use result.output
    pass
```

## Task Type Detection

The system can automatically detect task types:

1. **Metadata-based**: Task has `metadata.type` field
2. **Keyword-based**: Detector checks task title/description for keywords
3. **Custom detectors**: Register custom detection logic

```python
detector = TaskTypeDetector()
detector.register_detector(
    TaskTypeDetector.keyword_detector({
        "coding": "code,implement,function",
        "writing": "write,document,article"
    })
)
```

## Configuration

### Task-Level Configuration

```python
task = Task(
    id="task-1",
    title="My Task",
    description="Task description",
    metadata={
        "type": "coding",
        "language": "python",
        "config": {"timeout": 3600}
    }
)
```

### Domain-Level Configuration

```python
config = DomainConfig(
    domain_name="software_development",
    config_overrides={
        "checkpoint_interval": 20,
        "workspace_base": "code_workspaces"
    }
)
```

## Benefits

1. **Flexibility**: Works with any task type
2. **Extensibility**: Easy to add new task types and tools
3. **Reusability**: Same protocol for different domains
4. **Maintainability**: Clear separation of concerns
5. **Testability**: Each component can be tested independently

## Examples

See:
- `example_adapters.py`: Example adapters for different task types
- `example_task_agnostic.py`: Complete task-agnostic usage example

## Best Practices

1. **Create specific adapters** for each task type you need
2. **Use tools** for reusable capabilities
3. **Configure domains** for domain-specific behavior
4. **Validate tasks** in adapters to catch issues early
5. **Return artifacts** so the system can track outputs
6. **Handle errors** gracefully in adapters

