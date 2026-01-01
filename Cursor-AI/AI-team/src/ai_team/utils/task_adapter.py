"""
Task Adapter System - Makes the protocol task-agnostic.
Allows different task types to be handled through adapters.
"""

from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any, Callable, Tuple
from dataclasses import dataclass, field
from ..agents.agent_coordinator import Task, TaskStatus
from datetime import datetime


@dataclass
class TaskContext:
    """Context information for task execution"""
    task: Task
    agent_id: str
    workspace_path: Optional[str] = None
    config: Dict[str, Any] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.config is None:
            self.config = {}
        if self.metadata is None:
            self.metadata = {}


class TaskAdapter(ABC):
    """
    Base adapter for different task types.
    Each task type (coding, writing, analysis, etc.) implements this interface.
    """
    
    def __init__(self, task_type: str, config: Optional[Dict[str, Any]] = None):
        self.task_type = task_type
        self.config = config or {}
    
    @abstractmethod
    def can_handle(self, task: Task) -> bool:
        """Check if this adapter can handle the given task"""
        pass
    
    @abstractmethod
    def validate_task(self, task: Task) -> tuple[bool, List[str]]:
        """
        Validate that a task is properly configured for this adapter.
        Returns (is_valid, list_of_issues)
        """
        pass
    
    @abstractmethod
    def prepare_context(self, task: Task, agent_id: str) -> TaskContext:
        """Prepare execution context for the task"""
        pass
    
    @abstractmethod
    def execute(self, context: TaskContext) -> bool:
        """
        Execute the task.
        Returns True if successful, False otherwise.
        """
        pass
    
    @abstractmethod
    def get_artifacts(self, context: TaskContext) -> List[str]:
        """Get list of artifacts created by the task"""
        pass
    
    def cleanup(self, context: TaskContext):
        """Cleanup after task execution (optional)"""
        pass


class WorkExecutor(ABC):
    """
    Generic work executor interface.
    Different executors can handle different types of work.
    """
    
    @abstractmethod
    def execute(self, context: TaskContext) -> bool:
        """Execute the work. Returns True if successful."""
        pass
    
    @abstractmethod
    def get_progress(self, context: TaskContext) -> int:
        """Get current progress (0-100)"""
        pass
    
    @abstractmethod
    def get_checkpoint_info(self, context: TaskContext) -> Dict[str, str]:
        """Get checkpoint information (changes, next_steps)"""
        pass


class TaskAdapterRegistry:
    """
    Registry for task adapters.
    Allows registering adapters for different task types.
    """
    
    def __init__(self):
        self.adapters: Dict[str, TaskAdapter] = {}
        self.type_matchers: List[tuple[Callable[[Task], bool], TaskAdapter]] = []
    
    def register(self, adapter: TaskAdapter, priority: int = 0):
        """
        Register a task adapter.
        Priority: higher priority adapters are checked first.
        """
        self.adapters[adapter.task_type] = adapter
        # Add to type matchers with priority
        self.type_matchers.append((priority, lambda t: adapter.can_handle(t), adapter))
        # Sort by priority (descending)
        self.type_matchers.sort(key=lambda x: x[0], reverse=True)
    
    def get_adapter(self, task: Task) -> Optional[TaskAdapter]:
        """Get appropriate adapter for a task"""
        # Try type-based matching first
        task_type = task.metadata.get('type') if hasattr(task, 'metadata') else None
        if task_type and task_type in self.adapters:
            adapter = self.adapters[task_type]
            if adapter.can_handle(task):
                return adapter
        
        # Try matchers
        for priority, matcher, adapter in self.type_matchers:
            if matcher(task):
                return adapter
        
        return None
    
    def get_all_adapters(self) -> List[TaskAdapter]:
        """Get all registered adapters"""
        return list(self.adapters.values())


class GenericTaskAdapter(TaskAdapter):
    """
    Generic task adapter that can handle any task type.
    Uses a configurable executor function.
    """
    
    def __init__(
        self,
        task_type: str = "generic",
        executor: Optional[Callable[[TaskContext], bool]] = None,
        config: Optional[Dict[str, Any]] = None
    ):
        super().__init__(task_type, config)
        self.executor = executor or self._default_executor
    
    def can_handle(self, task: Task) -> bool:
        """Generic adapter can handle any task"""
        return True
    
    def validate_task(self, task: Task) -> tuple[bool, List[str]]:
        """Basic validation"""
        issues = []
        if not task.title:
            issues.append("Task missing title")
        if not task.description:
            issues.append("Task missing description")
        return len(issues) == 0, issues
    
    def prepare_context(self, task: Task, agent_id: str) -> TaskContext:
        """Prepare generic context"""
        return TaskContext(
            task=task,
            agent_id=agent_id,
            config=self.config.copy(),
            metadata={}
        )
    
    def execute(self, context: TaskContext) -> bool:
        """Execute using configured executor"""
        return self.executor(context)
    
    def get_artifacts(self, context: TaskContext) -> List[str]:
        """Get artifacts from context metadata"""
        return context.metadata.get('artifacts', [])
    
    def _default_executor(self, context: TaskContext) -> bool:
        """
        Default executor.
        
        IMPORTANT: Returning True without doing any work causes false "COMPLETED"
        states (tasks appear done while no artifacts/requirements are implemented).
        If a caller wants a generic adapter to succeed, they MUST provide an executor.
        """
        print(f"[{context.agent_id}] [ERROR] No executor configured for task '{context.task.id}'.")
        print(f"[{context.agent_id}] [ERROR] Configure a real executor (e.g., Cursor CLI-backed) or a specialized adapter.")
        return False


class TaskTypeDetector:
    """
    Detects task type from task properties.
    Can be extended with custom detection logic.
    """
    
    def __init__(self):
        self.detectors: List[Callable[[Task], Optional[str]]] = []
    
    def register_detector(self, detector: Callable[[Task], Optional[str]]):
        """Register a task type detector"""
        self.detectors.append(detector)
    
    def detect(self, task: Task) -> Optional[str]:
        """Detect task type"""
        for detector in self.detectors:
            task_type = detector(task)
            if task_type:
                return task_type
        return None
    
    @staticmethod
    def keyword_detector(keywords: Dict[str, str]) -> Callable[[Task], Optional[str]]:
        """
        Create a keyword-based detector.
        keywords: {task_type: "keyword1,keyword2"}
        """
        def detector(task: Task) -> Optional[str]:
            text = f"{task.title} {task.description}".lower()
            for task_type, keyword_list in keywords.items():
                for keyword in keyword_list.split(','):
                    if keyword.strip().lower() in text:
                        return task_type
            return None
        return detector


class TaskConfig:
    """
    Configuration for task execution.
    Can be customized per task type or domain.
    """
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self._defaults = {
            "checkpoint_interval": 30,  # minutes
            "max_retries": 3,
            "timeout": 3600,  # seconds
            "workspace_base": "workspaces",
            "artifact_base": "artifacts"
        }
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get config value"""
        return self.config.get(key, self._defaults.get(key, default))
    
    def set(self, key: str, value: Any):
        """Set config value"""
        self.config[key] = value
    
    def merge(self, other: Dict[str, Any]):
        """Merge another config dict"""
        self.config.update(other)
    
    def for_task_type(self, task_type: str) -> Dict[str, Any]:
        """Get config specific to a task type"""
        type_config = self.config.get(f"{task_type}_config", {})
        base_config = {k: v for k, v in self.config.items() if not k.endswith("_config")}
        return {**base_config, **type_config}

