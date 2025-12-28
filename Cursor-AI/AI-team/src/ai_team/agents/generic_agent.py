"""
Generic Agent - Task-agnostic agent that works with any task type.
Uses adapters and tools to handle different task types.
"""

from typing import Optional, List
from .agent import Agent, IncrementalWorkMixin
from .agent_coordinator import Task, TaskStatus
from ..utils.task_adapter import (
    TaskAdapter, TaskAdapterRegistry, TaskContext, GenericTaskAdapter
)
from ..utils.tool_system import ToolRegistry, ToolExecutor
from ..utils.conflict_prevention import LockType
import time


class GenericAgent(Agent, IncrementalWorkMixin):
    """
    Generic agent that can work on any task type using adapters.
    Task-agnostic implementation.
    """
    
    def __init__(
        self,
        agent_id: str,
        coordinator,
        specialization: str = "",
        adapter_registry: Optional[TaskAdapterRegistry] = None,
        tool_registry: Optional[ToolRegistry] = None
    ):
        super().__init__(agent_id, coordinator, specialization)
        self.adapter_registry = adapter_registry or TaskAdapterRegistry()
        self.tool_registry = tool_registry
        self.tool_executor: Optional[ToolExecutor] = None
        self.current_context: Optional[TaskContext] = None
    
    def work(self, task: Task) -> bool:
        """Work on task using appropriate adapter"""
        print(f"\n[{self.agent_id}] Working on: {task.title}")
        
        # Get appropriate adapter
        adapter = self.adapter_registry.get_adapter(task)
        if not adapter:
            # Fallback to generic adapter
            adapter = GenericTaskAdapter()
            print(f"  [{self.agent_id}] Using generic adapter")
        else:
            print(f"  [{self.agent_id}] Using adapter: {adapter.task_type}")
        
        # Validate task
        is_valid, issues = adapter.validate_task(task)
        if not is_valid:
            print(f"  [{self.agent_id}] ✗ Task validation failed: {issues}")
            self.send_status_update(
                task.id,
                TaskStatus.BLOCKED,
                message=f"Validation failed: {', '.join(issues)}"
            )
            return False
        
        # Prepare context
        self.current_context = adapter.prepare_context(task, self.agent_id)
        if self.coordinator.conflict_prevention:
            self.current_context.workspace_path = self.workspace_path
        
        # Setup tool executor if available
        if self.tool_registry:
            self.tool_executor = ToolExecutor(self.tool_registry, self.current_context)
        
        # Break work into increments
        increments = self.create_increments(task, [
            "Prepare workspace",
            "Execute task",
            "Validate results",
            "Finalize"
        ])
        
        # Work through increments
        for increment in increments:
            if not self._running:
                return False
            
            self._pause_event.wait()
            
            print(f"  [{self.agent_id}] {increment['description']}...")
            
            # Send checkpoint
            self.send_checkpoint(
                task.id,
                progress=increment["progress_end"],
                changes=f"Completed: {increment['description']}",
                next_steps=f"Next: increment {increment['number'] + 1}" if increment['number'] < increment['total'] else "Finalizing"
            )
            
            time.sleep(0.3)  # Simulate work
        
        # Execute task using adapter
        try:
            success = adapter.execute(self.current_context)
            
            if not success:
                print(f"  [{self.agent_id}] ✗ Task execution failed")
                return False
            
            # Get artifacts
            artifacts = adapter.get_artifacts(self.current_context)
            
            # Validate changes if conflict prevention enabled
            if self.coordinator.conflict_prevention and artifacts:
                is_valid, issues = self.validate_changes(artifacts)
                if not is_valid:
                    print(f"  [{self.agent_id}] ✗ Validation failed: {issues}")
                    return False
            
            # Complete task
            self.complete_task(
                task.id,
                result=f"Successfully completed {task.title}",
                artifacts=artifacts,
                tests="Validation passed"
            )
            
            # Cleanup
            adapter.cleanup(self.current_context)
            self.current_context = None
            
            print(f"  [{self.agent_id}] ✓ Completed: {task.title}")
            return True
            
        except Exception as e:
            print(f"  [{self.agent_id}] ✗ Error: {e}")
            self.send_status_update(
                task.id,
                TaskStatus.FAILED,
                message=f"Execution error: {str(e)}"
            )
            return False
    
    def use_tool(self, tool_name: str, *args, **kwargs):
        """Use a tool from the tool registry"""
        if not self.tool_executor:
            print(f"  [{self.agent_id}] No tool executor available")
            return None
        
        result = self.tool_executor.execute(tool_name, *args, **kwargs)
        if not result.success:
            print(f"  [{self.agent_id}] Tool '{tool_name}' failed: {result.error}")
        return result

