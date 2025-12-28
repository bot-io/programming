"""
Task Queue System for managing incremental tasks.
Provides priority queues, dependency resolution, and task scheduling.
"""

from typing import List, Dict, Optional
from collections import deque
from ..agents.agent_coordinator import Task, TaskStatus
from datetime import datetime


class TaskQueue:
    """
    Manages a queue of tasks with dependency resolution and prioritization.
    """

    def __init__(self):
        self.queue: deque = deque()
        self.tasks: Dict[str, Task] = {}
        self.completed_tasks: set = set()

    def add_task(self, task: Task):
        """Add a task to the queue"""
        self.tasks[task.id] = task

    def add_tasks(self, tasks: List[Task]):
        """Add multiple tasks"""
        for task in tasks:
            self.add_task(task)

    def get_ready_tasks(self) -> List[Task]:
        """Get tasks that are ready to be worked on (dependencies met)"""
        ready = []
        for task in self.tasks.values():
            if task.id in self.completed_tasks:
                continue
            
            # Check if all dependencies are completed
            if not task.dependencies:
                ready.append(task)
            elif all(dep_id in self.completed_tasks for dep_id in task.dependencies):
                ready.append(task)
        
        return ready

    def mark_completed(self, task_id: str):
        """Mark a task as completed"""
        if task_id in self.tasks:
            self.completed_tasks.add(task_id)
            self.tasks[task_id].status = TaskStatus.COMPLETED

    def get_next_task(self, agent_specialization: Optional[str] = None) -> Optional[Task]:
        """
        Get the next task from the queue.
        Prioritizes by:
        1. Tasks with no dependencies first
        2. Tasks matching agent specialization
        3. Tasks with fewer remaining dependencies
        """
        ready_tasks = self.get_ready_tasks()
        
        if not ready_tasks:
            return None

        # Filter by specialization if provided
        if agent_specialization:
            matching = [
                t for t in ready_tasks
                if agent_specialization.lower() in t.title.lower() or
                   agent_specialization.lower() in t.description.lower()
            ]
            if matching:
                ready_tasks = matching

        # Prioritize: fewer dependencies first, then by estimated hours
        ready_tasks.sort(key=lambda t: (len(t.dependencies), t.estimated_hours))
        
        return ready_tasks[0] if ready_tasks else None

    def get_blocked_tasks(self) -> List[Task]:
        """Get tasks that are blocked by incomplete dependencies"""
        blocked = []
        for task in self.tasks.values():
            if task.id in self.completed_tasks:
                continue
            
            incomplete_deps = [
                dep_id for dep_id in task.dependencies
                if dep_id not in self.completed_tasks
            ]
            
            if incomplete_deps:
                blocked.append((task, incomplete_deps))
        
        return blocked

    def get_progress(self) -> Dict:
        """Get overall progress statistics"""
        total = len(self.tasks)
        completed = len(self.completed_tasks)
        ready = len(self.get_ready_tasks())
        blocked = len(self.get_blocked_tasks())
        in_progress = len([
            t for t in self.tasks.values()
            if t.status == TaskStatus.IN_PROGRESS
        ])
        
        return {
            "total": total,
            "completed": completed,
            "ready": ready,
            "blocked": blocked,
            "in_progress": in_progress,
            "pending": total - completed - ready - blocked - in_progress,
            "completion_percentage": (completed / total * 100) if total > 0 else 0
        }

    def get_critical_path(self) -> List[str]:
        """
        Calculate critical path - longest sequence of dependent tasks.
        Returns list of task IDs in order.
        """
        # Simple implementation: find longest dependency chain
        def get_chain_length(task_id: str, visited: set) -> int:
            if task_id in visited or task_id not in self.tasks:
                return 0
            
            visited.add(task_id)
            task = self.tasks[task_id]
            
            if not task.dependencies:
                return 1
            
            max_chain = max(
                [get_chain_length(dep_id, visited.copy()) for dep_id in task.dependencies],
                default=0
            )
            return max_chain + 1

        # Find task with longest chain
        max_length = 0
        critical_task = None
        
        for task_id in self.tasks:
            length = get_chain_length(task_id, set())
            if length > max_length:
                max_length = length
                critical_task = task_id

        # Reconstruct path
        if not critical_task:
            return []

        path = []
        current = critical_task
        visited = set()

        def build_path(task_id: str):
            if task_id in visited or task_id not in self.tasks:
                return
            
            visited.add(task_id)
            task = self.tasks[task_id]
            
            # Add dependencies first
            for dep_id in task.dependencies:
                build_path(dep_id)
            
            path.append(task_id)

        build_path(critical_task)
        return path

    def estimate_completion_time(self) -> float:
        """
        Estimate total time to completion based on:
        - Remaining tasks
        - Dependencies (parallel work possible)
        - Critical path
        """
        if not self.tasks:
            return 0.0

        # Get critical path length (sequential work)
        critical_path = self.get_critical_path()
        critical_time = sum(
            self.tasks[t_id].estimated_hours
            for t_id in critical_path
            if t_id not in self.completed_tasks
        )

        # Add time for tasks not on critical path (can be done in parallel)
        remaining_tasks = [
            t for t in self.tasks.values()
            if t.id not in self.completed_tasks and t.id not in critical_path
        ]
        
        if remaining_tasks:
            # Assume some parallelization
            parallel_time = max(t.estimated_hours for t in remaining_tasks) * 0.7
            return critical_time + parallel_time
        
        return critical_time

